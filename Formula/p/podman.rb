class Podman < Formula
  desc "Tool for managing OCI containers and pods"
  homepage "https://podman.io/"
  url "https://github.com/containers/podman/archive/refs/tags/v5.3.2.tar.gz"
  sha256 "e7d7abf2d4ecae7217af017a4199d555563721bf6c3ae52e68704ee8268c432b"
  license all_of: ["Apache-2.0", "GPL-3.0-or-later"]
  revision 1
  head "https://github.com/containers/podman.git", branch: "main"

  # There can be a notable gap between when a version is tagged and a
  # corresponding release is created and upstream uses GitHub releases to
  # indicate when a version is released, so we check the "latest" release
  # instead of the Git tags. Maintainers confirmed:
  # https://github.com/Homebrew/homebrew-core/pull/205162#issuecomment-2607793814
  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "40d0bce7840fc2b4e1c38850cd99e3788cd35bfa2a9bce3e190ac2ab14f7fa41"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "807f8831aef3b4fbd268409bd43f3d1e027b24ff0b8c6a420ec18cc31b14a3e6"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "ca005bd6f119fc84cbd32e9dbfdac9e72d2024591489d23b63e61f8f30e6fb70"
    sha256 cellar: :any_skip_relocation, sonoma:        "ff76012e8d04d2112214807873e2309834f659fc3d8b3927703d1e09aa1f0713"
    sha256 cellar: :any_skip_relocation, ventura:       "3e76b6d472c6cef038eab844853d151583e9ade1d6bc35a87aa521f53fd57b8f"
    sha256                               x86_64_linux:  "4b7198518ea7728c16aa8c14d9d5ba24f84af23c3fe6cfbeb16fbde63e9362e7"
  end

  depends_on "go" => :build
  depends_on "go-md2man" => :build
  depends_on macos: :ventura # see discussions in https://github.com/containers/podman/issues/22121
  uses_from_macos "python" => :build

  on_macos do
    depends_on "make" => :build
  end

  on_linux do
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "pkgconf" => :build
    depends_on "protobuf" => :build
    depends_on "rust" => :build
    depends_on "conmon"
    depends_on "crun"
    depends_on "fuse-overlayfs"
    depends_on "gpgme"
    depends_on "libseccomp"
    depends_on "passt"
    depends_on "slirp4netns"
    depends_on "systemd"
  end

  resource "gvproxy" do
    on_macos do
      url "https://github.com/containers/gvisor-tap-vsock/archive/refs/tags/v0.8.1.tar.gz"
      sha256 "9b7fb12dfc37b0a727f2209ff8b557c4ec922d11cec30a778c192da360db4a2f"
    end
  end

  resource "vfkit" do
    on_macos do
      url "https://github.com/crc-org/vfkit/archive/refs/tags/v0.6.0.tar.gz"
      sha256 "4efaf318729101076d3bf821baf88e5f5bf89374684b35b2674c824a76feafdf"
    end
  end

  resource "catatonit" do
    on_linux do
      url "https://github.com/openSUSE/catatonit/archive/refs/tags/v0.2.1.tar.gz"
      sha256 "771385049516fdd561fbb9164eddf376075c4c7de3900a8b18654660172748f1"
    end
  end

  resource "netavark" do
    on_linux do
      url "https://github.com/containers/netavark/archive/refs/tags/v1.13.1.tar.gz"
      sha256 "b3698021677fb3b0fd1dc5f669fd62b49a7f4cf26bb70f977663f6d1a5046a31"
    end
  end

  resource "aardvark-dns" do
    on_linux do
      url "https://github.com/containers/aardvark-dns/archive/refs/tags/v1.13.1.tar.gz"
      sha256 "8c21dbdb6831d61d52dde6ebc61c851cfc96ea674cf468530b44de6ee9e6f49e"
    end
  end

  def install
    if OS.mac?
      ENV["CGO_ENABLED"] = "1"

      system "gmake", "podman-remote"
      bin.install "bin/darwin/podman" => "podman-remote"
      bin.install_symlink bin/"podman-remote" => "podman"

      system "gmake", "podman-mac-helper"
      bin.install "bin/darwin/podman-mac-helper" => "podman-mac-helper"

      resource("gvproxy").stage do
        system "gmake", "gvproxy"
        (libexec/"podman").install "bin/gvproxy"
      end

      resource("vfkit").stage do
        ENV["CGO_ENABLED"] = "1"
        ENV["CGO_CFLAGS"] = "-mmacosx-version-min=11.0"
        ENV["GOOS"]="darwin"
        arch = Hardware::CPU.intel? ? "amd64" : Hardware::CPU.arch.to_s
        system "gmake", "out/vfkit-#{arch}"
        (libexec/"podman").install "out/vfkit-#{arch}" => "vfkit"
      end

      system "gmake", "podman-remote-darwin-docs"
      man1.install Dir["docs/build/remote/darwin/*.1"]

      bash_completion.install "completions/bash/podman"
      zsh_completion.install "completions/zsh/_podman"
      fish_completion.install "completions/fish/podman.fish"
    else
      paths = Dir["**/*.go"].select do |file|
        (buildpath/file).read.lines.grep(%r{/etc/containers/}).any?
      end
      inreplace paths, "/etc/containers/", etc/"containers/"

      ENV.O0
      ENV["PREFIX"] = prefix
      ENV["HELPER_BINARIES_DIR"] = opt_libexec/"podman"

      system "make"
      system "make", "install", "install.completions"

      (prefix/"etc/containers/policy.json").write <<~JSON
        {"default":[{"type":"insecureAcceptAnything"}]}
      JSON

      (prefix/"etc/containers/storage.conf").write <<~EOS
        [storage]
        driver="overlay"
      EOS

      (prefix/"etc/containers/registries.conf").write <<~EOS
        unqualified-search-registries=["docker.io"]
      EOS

      resource("catatonit").stage do
        system "./autogen.sh"
        system "./configure"
        system "make"
        mv "catatonit", libexec/"podman/"
      end

      resource("netavark").stage do
        system "make"
        mv "bin/netavark", libexec/"podman/"
      end

      resource("aardvark-dns").stage do
        system "make"
        mv "bin/aardvark-dns", libexec/"podman/"
      end
    end
  end

  def caveats
    on_linux do
      <<~EOS
        You need "newuidmap" and "newgidmap" binaries installed system-wide
        for rootless containers to work properly.
      EOS
    end
    on_macos do
      <<~EOS
        In order to run containers locally, podman depends on a Linux kernel.
        One can be started manually using `podman machine` from this package.
        To start a podman VM automatically at login, also install the cask
        "podman-desktop".
      EOS
    end
  end

  service do
    run linux: [opt_bin/"podman", "system", "service", "--time", "0"]
    environment_variables PATH: std_service_path_env
    working_dir HOMEBREW_PREFIX
  end

  test do
    assert_match "podman-remote version #{version}", shell_output("#{bin}/podman-remote -v")
    out = shell_output("#{bin}/podman-remote info 2>&1", 125)
    assert_match "Cannot connect to Podman", out

    if OS.mac?
      # This test will fail if VM images are not built yet. Re-run after VM images are built if this is the case
      # See https://github.com/Homebrew/homebrew-core/pull/166471
      out = shell_output("#{bin}/podman-remote machine init homebrew-testvm")
      assert_match "Machine init complete", out
      system bin/"podman-remote", "machine", "rm", "-f", "homebrew-testvm"
    else
      assert_equal %w[podman podman-remote podmansh]
        .map { |binary| File.join(bin, binary) }.sort, Dir[bin/"*"]
      assert_equal %W[
        #{libexec}/podman/catatonit
        #{libexec}/podman/netavark
        #{libexec}/podman/aardvark-dns
        #{libexec}/podman/quadlet
        #{libexec}/podman/rootlessport
      ].sort, Dir[libexec/"podman/*"]
      out = shell_output("file #{libexec}/podman/catatonit")
      assert_match "statically linked", out
    end
  end
end
