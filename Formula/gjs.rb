class Gjs < Formula
  desc "JavaScript Bindings for GNOME"
  homepage "https://gitlab.gnome.org/GNOME/gjs/wikis/Home"
  url "https://download.gnome.org/sources/gjs/1.70/gjs-1.70.0.tar.xz"
  sha256 "4b0629341a318a02374e113ab97f9a9f3325423269fc1e0b043a5ffb01861c5f"
  license all_of: ["LGPL-2.0-or-later", "MIT"]

  bottle do
    sha256 big_sur:  "895a1fd43b095dc790ed323733da4cc6bfcffbcf66c665b0936e9cda1597d4fb"
    sha256 catalina: "cca0c61978c5bc68b939519de12e608754a9d0fec50685d29be0af0cf3a6ca5f"
    sha256 mojave:   "c2e0750012d24e80e5585aefc529b96b5eff4c02ae8f5d7e62a22b04e113dc9b"
  end

  depends_on "autoconf@2.13" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.8" => :build
  depends_on "rust" => :build
  depends_on "six" => :build
  depends_on "gobject-introspection"
  depends_on "gtk+3"
  depends_on "llvm"
  depends_on "nspr"
  depends_on "readline"

  resource "mozjs78" do
    url "https://archive.mozilla.org/pub/firefox/releases/78.10.1esr/source/firefox-78.10.1esr.source.tar.xz"
    sha256 "c41f45072b0eb84b9c5dcb381298f91d49249db97784c7e173b5f210cd15cf3f"
  end

  def install
    ENV.cxx11

    resource("mozjs78").stage do
      inreplace "build/moz.configure/toolchain.configure",
                "sdk_max_version = Version('10.15.4')",
                "sdk_max_version = Version('11.99')"
      inreplace "config/rules.mk",
                "-install_name $(_LOADER_PATH)/$(SHARED_LIBRARY) ",
                "-install_name #{lib}/$(SHARED_LIBRARY) "
      inreplace "old-configure", "-Wl,-executable_path,${DIST}/bin", ""

      mkdir("build") do
        ENV["PYTHON"] = which("python3")
        ENV["_MACOSX_DEPLOYMENT_TARGET"] = ENV["MACOSX_DEPLOYMENT_TARGET"]
        ENV["CC"] = Formula["llvm"].opt_bin/"clang"
        ENV["CXX"] = Formula["llvm"].opt_bin/"clang++"
        ENV.prepend_path "PATH", buildpath/"autoconf/bin"
        system "../js/src/configure", "--prefix=#{prefix}",
                              "--with-system-nspr",
                              "--with-system-zlib",
                              "--with-system-icu",
                              "--enable-readline",
                              "--enable-shared-js",
                              "--enable-optimize",
                              "--enable-release",
                              "--with-intl-api",
                              "--disable-jemalloc"
        system "make"
        system "make", "install"
        rm Dir["#{bin}/*"]
      end
      # headers were installed as softlinks, which is not acceptable
      cd(include.to_s) do
        `find . -type l`.chomp.split.each do |link|
          header = File.readlink(link)
          rm link
          cp header, link
        end
      end
      ENV.append_path "PKG_CONFIG_PATH", "#{lib}/pkgconfig"
      rm "#{lib}/libjs_static.ajs"
    end

    # ensure that we don't run the meson post install script
    ENV["DESTDIR"] = "/"

    args = std_meson_args + %w[
      -Dprofiler=disabled
      -Dinstalled_tests=false
      -Dbsymbolic_functions=false
      -Dskip_dbus_tests=true
      -Dskip_gtk_tests=true
    ]

    mkdir "build" do
      system "meson", *args, ".."
      system "ninja", "-v"
      system "ninja", "install", "-v"
    end
  end

  def post_install
    system "#{Formula["glib"].opt_bin}/glib-compile-schemas", "#{HOMEBREW_PREFIX}/share/glib-2.0/schemas"
  end

  test do
    (testpath/"test.js").write <<~EOS
      #!/usr/bin/env gjs
      const GLib = imports.gi.GLib;
      if (31 != GLib.Date.get_days_in_month(GLib.DateMonth.JANUARY, 2000))
        imports.system.exit(1)
    EOS
    system "#{bin}/gjs", "test.js"
  end
end
