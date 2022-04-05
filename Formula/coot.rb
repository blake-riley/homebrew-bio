class Coot < Formula
  include Language::Python::Virtualenv

  desc "Crystallographic Object-Oriented Toolkit"
  homepage "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/"
  url "https://github.com/pemsley/coot/archive/ff8c399abd621bd8366466b2154d0783855607cd.tar.gz"
  version "1.0.01-pre"
  sha256 "f117475c3650fccd01dfcefb47d221d5143a57c18f05def558441cf870de7f79"
  license any_of: ["GPL-3.0-only", "LGPL-3.0-only", "GPL-2.0-or-later"]

  head do
    url "https://github.com/pemsley/coot.git", branch: "gtk3"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "swig" => :build
  depends_on "adwaita-icon-theme" # display icons
  depends_on "boost"
  depends_on "boost-python3"
  depends_on "brewsci/bio/clipper4coot"
  depends_on "brewsci/bio/libccp4"
  depends_on "brewsci/bio/mmdb2"
  depends_on "brewsci/bio/raster3d"
  depends_on "brewsci/bio/ssm"
  depends_on "glib"
  depends_on "goocanvas"
  depends_on "gsl"
  depends_on "gtk+3"
  depends_on "libepoxy"
  depends_on "numpy"
  depends_on "py3cairo"
  depends_on "pygobject3"
  depends_on "python@3.9"
  depends_on "rdkit"

  uses_from_macos "curl"

  resource "reference-structures" do
    url "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/dependencies/reference-structures.tar.gz"
    sha256 "44db38506f0f90c097d4855ad81a82a36b49cd1e3ffe7d6ee4728b15109e281a"
  end

  resource "monomers" do
    url "https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/dependencies/refmac-monomer-library.tar.gz"
    sha256 "03562eec612103a48bd114cfe0d171943e88f94b84610d16d542cda138e5f36b"
  end

  patch :DATA

  def install
    ENV.cxx11
    ENV.libcxx

    # libtool -> glibtool for macOS
    inreplace "autogen.sh", "libtool", "glibtool"
    system "./autogen.sh"

    # Get Python location
    python_executable = Formula["python@3.9"].opt_bin/"python3"
    xy = Language::Python.major_minor_version python_executable
    ENV["PYTHONPATH"] = libexec/"lib/python#{xy}/site-packages"

    # FFTW2.1.5 location, included in the Clipper4coot Formula
    fftw2_prefix = Formula["clipper4coot"].opt_prefix/"fftw2"
    ENV.append "LDFLAGS", "-L#{Formula["clipper4coot"].opt_prefix}/fftw2/lib"
    ENV.append "CPPFLAGS", "-I#{Formula["clipper4coot"].opt_prefix}/fftw2/include"

    # Boost root
    boost_prefix = Formula["boost"].opt_prefix
    boost_python_lib = Formula["boost-python3"].opt_lib

    # set RDKit CPPFLAGS (required)
    ENV.append "CPPFLAGS", "-I#{Formula["rdkit"].opt_include}/rdkit"

    # patch to use -std=c++14 for '--with-enhanced-ligand-tools'
    inreplace "configure.ac", "CXXFLAGS -std=c++11", "CXXFLAGS -std=c++14"

    args = %W[
      --prefix=#{prefix}
      --with-boost=#{boost_prefix}
      --with-boost-libdir=#{boost_python_lib}
      --with-fftw-prefix=#{fftw2_prefix}
      --with-enhanced-ligand-tools
    ]

    rdkit_libs = %W[
      "-L#{Formula["rdkit"].opt_lib}
      -lRDKitMolDraw2D
      -lRDKitForceFieldHelpers
      -lRDKitDescriptors
      -lRDKitForceField
      -lRDKitSubstructMatch
      -lRDKitOptimizer
      -lRDKitDistGeomHelpers
      -lRDKitDistGeometry
      -lRDKitAlignment
      -lRDKitEigenSolvers
      -lRDKitDepictor
      -lRDKitMolChemicalFeatures
      -lRDKitFileParsers
      -lRDKitRDGeometryLib
      -lRDKitGraphMol
      -lRDKitSmilesParse
      -lRDKitDataStructs
      -lRDKitRDGeneral
      -lboost_python39"
    ]

    rdkit_cxxflags = %W[
      "-I#{Formula["rdkit"].opt_include}/rdkit
      -DRDKIT_HAS_CAIRO_SUPPORT"
    ]

    args << "RDKIT_LIBS=#{rdkit_libs.join(" ")}"
    args << "RDKIT_CXXFLAGS=#{rdkit_cxxflags.join(" ")}"
    ENV.append_to_cflags "-fPIC" if OS.linux?
    system "./configure", *args
    system "make"
    system "make", "install"

    # install reference data
    # install data, #{pkgshare} is /path/to/share/coot
    (pkgshare/"reference-structures").install resource("reference-structures")
    (pkgshare/"lib/data/monomers").install resource("monomers")
  end

  # test block is not tested now.
  test do
    assert_match "-I#{include}", shell_output("pkg-config --cflags mmdb2")
  end
end

__END__

diff --git a/utils/backward.hpp b/utils/backward.hpp
index 195ca8f2d..e661ce7b6 100644
--- a/utils/backward.hpp
+++ b/utils/backward.hpp
@@ -4157,7 +4157,11 @@ public:
 #elif defined(__arm__)
     error_addr = reinterpret_cast<void *>(uctx->uc_mcontext.arm_pc);
 #elif defined(__aarch64__)
-    error_addr = reinterpret_cast<void *>(uctx->uc_mcontext.pc);
+    #if defined(__APPLE__)
+      error_addr = reinterpret_cast<void *>(uctx->uc_mcontext->__ss.__pc);
+    #else
+      error_addr = reinterpret_cast<void *>(uctx->uc_mcontext.pc);
+    #endif
 #elif defined(__mips__)
     error_addr = reinterpret_cast<void *>(
         reinterpret_cast<struct sigcontext *>(&uctx->uc_mcontext)->sc_pc);


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


@@ -147,7 +143,7 @@ export COOT_STANDARD_RESIDUES
 # export COOT_REFMAC_LIB_DIR
 export COOT_PYTHON_DIR
 # export PYTHONPATH
-export PYTHONHOME
+# export PYTHONHOME
 export COOT_SCHEME_DIR
 export COOT_REF_STRUCTS
 export COOT_RESOURCES_FILE
