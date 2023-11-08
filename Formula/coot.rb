class Coot < Formula
  include Language::Python::Virtualenv

  desc "Crystallographic Object-Oriented Toolkit"
  homepage "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/"
  url "https://github.com/pemsley/coot/archive/d6d8ed5ea90c4a493c6d6b19ce9ea7833a32963f.tar.gz"
  sha256 "6dbdb588b14049316075714a1e5ba204e51b602b1f5138fb1ba76072983ed08f"
  license any_of: ["GPL-3.0-only", "LGPL-3.0-only", "GPL-2.0-or-later"]
  version "1.1.1"

  head do
    url "https://github.com/pemsley/coot.git", branch: "main"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "glm" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "swig" => :build
  depends_on "adwaita-icon-theme" # display icons
  depends_on "boost"
  depends_on "boost-python3"
  depends_on "brewsci/bio/clipper4coot"
  depends_on "brewsci/bio/gemmi"
  depends_on "brewsci/bio/libccp4"
  depends_on "brewsci/bio/mmdb2"
  depends_on "brewsci/bio/raster3d"
  depends_on "brewsci/bio/ssm"
  depends_on "dwarfutils"
  depends_on "glfw"
  depends_on "glib"
  depends_on "gmp"
  depends_on "gsl"
  depends_on "gtk4"
  depends_on "libepoxy"
  depends_on "numpy"
  depends_on "py3cairo"
  depends_on "python@3.10"
  depends_on "rdkit"
  depends_on "sqlite"
  depends_on "pygobject3"

  uses_from_macos "curl"

  resource "reference-structures" do
    url "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/dependencies/reference-structures.tar.gz"
    sha256 "44db38506f0f90c097d4855ad81a82a36b49cd1e3ffe7d6ee4728b15109e281a"
    version "1"
  end

  resource "monomers" do
    url "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/dependencies/refmac-monomer-library.tar.gz"
    sha256 "03562eec612103a48bd114cfe0d171943e88f94b84610d16d542cda138e5f36b"
    version "1"
  end

  patch :DATA

  def install
    ENV.cxx11
    ENV.libcxx

    # libtool -> glibtool for macOS
    inreplace "autogen.sh", "libtool", "glibtool"
    system "./autogen.sh"

    if OS.mac?
      inreplace "./configure", "$wl-flat_namespace", ""
      inreplace "./configure", "$wl-undefined ${wl}suppress", "-undefined dynamic_lookup"
    end

    # Get Python location
    python_executable = Formula["python@3.9"].opt_bin/"python3"
    xy = Language::Python.major_minor_version python_executable
    ENV["PYTHONPATH"] = libexec/"lib/python#{xy}/site-packages"

    # Set Boost, RDKit, and FFTW2 root
    boost_prefix = Formula["boost"].opt_prefix
    boost_python_lib = Formula["boost-python3"].opt_lib
    rdkit_prefix = Formula["rdkit"].opt_prefix
    fftw2_prefix = Formula["clipper4coot"].opt_prefix/"fftw2"

    # --with-enhanced-ligand-tools is no longer disabled.
    args = %W[
      --prefix=#{prefix}
      --with-enhanced-ligand-tools
      --with-boost=#{boost_prefix}
      --with-boost-libdir=#{boost_python_lib}
      --with-rdkit-prefix=#{rdkit_prefix}
      --with-fftw-prefix=#{fftw2_prefix}
      --with-backward
      --with-libdw
    ]

    ENV.append_to_cflags "-fPIC" if OS.linux?
    system "./configure", *args
    system "make"
    ENV.deparallelize { system 'make', 'install' }

    # install reference data
    # install data, #{pkgshare} is /path/to/share/coot
    (pkgshare/"reference-structures").install resource("reference-structures")
    (pkgshare/"lib/data/monomers").install resource("monomers")
  end

  # test block is not tested now.
  test do
    assert_match "Usage: coot", shell_output("#{bin}/coot --help 2>&1")
  end
end

__END__

diff --git a/src/coot.in b/src/coot.in
index 3b5ef61a0..3db17ea38 100755
--- a/src/coot.in
+++ b/src/coot.in
@@ -39,13 +39,15 @@ function check_for_no_graphics {
 current_exe_dir=$(dirname $0)
 systype=$(uname)

-if [ $systype = Darwin ] ; then
-    COOT_PREFIX="$(cd "$(dirname "$current_exe_dir")" 2>/dev/null && pwd)"
-else
-    unlinked_exe=$(readlink -f $0)
-    unlinked_exe_dir=$(dirname $unlinked_exe)
-    COOT_PREFIX=$(dirname $unlinked_exe_dir)
-fi
+# ht: https://stackoverflow.com/a/246128
+SOURCE=${BASH_SOURCE[0]}
+while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
+  DIR=$(cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd)
+  SOURCE=$(readlink "$SOURCE")
+  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
+done
+COOT_BIN_PREFIX=$(cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd)
+COOT_PREFIX=$(dirname $COOT_BIN_PREFIX)
 # echo COOT_PREFIX is $COOT_PREFIX