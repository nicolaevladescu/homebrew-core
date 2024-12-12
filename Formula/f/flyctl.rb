class Flyctl < Formula
  desc "Command-line tools for fly.io services"
  homepage "https://fly.io"
  url "https://github.com/superfly/flyctl.git",
      tag:      "v0.3.50",
      revision: "a9c2fb39a36edbff834da9d35704dd351203461b"
  license "Apache-2.0"
  head "https://github.com/superfly/flyctl.git", branch: "master"

  # Upstream tags versions like `v0.1.92` and `v2023.9.8` but, as of writing,
  # they only create releases for the former and those are the versions we use
  # in this formula. We could omit the date-based versions using a regex but
  # this uses the `GithubLatest` strategy, as the upstream repository also
  # contains over a thousand tags (and growing).
  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b4c3332e86798371e45b95bc7b622aae2d3540ab21539d074fd383fa4a3522ea"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "b4c3332e86798371e45b95bc7b622aae2d3540ab21539d074fd383fa4a3522ea"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "b4c3332e86798371e45b95bc7b622aae2d3540ab21539d074fd383fa4a3522ea"
    sha256 cellar: :any_skip_relocation, sonoma:        "21ca9a95b7dfcee665b7a18c249451eae8c0f6b968d58ae0e684e5f8fad71d0f"
    sha256 cellar: :any_skip_relocation, ventura:       "21ca9a95b7dfcee665b7a18c249451eae8c0f6b968d58ae0e684e5f8fad71d0f"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "2406abb5488f7881cff733ab46135a5f2bf66d12893a53e5ac9efe8e88ffdb17"
  end

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"
    ldflags = %W[
      -s -w
      -X github.com/superfly/flyctl/internal/buildinfo.buildDate=#{time.iso8601}
      -X github.com/superfly/flyctl/internal/buildinfo.buildVersion=#{version}
      -X github.com/superfly/flyctl/internal/buildinfo.commit=#{Utils.git_short_head}
    ]
    system "go", "build", *std_go_args(ldflags:), "-tags", "production"

    bin.install_symlink "flyctl" => "fly"

    generate_completions_from_executable(bin/"flyctl", "completion")
    generate_completions_from_executable(bin/"fly", "completion", base_name: "fly")
  end

  test do
    assert_match "flyctl v#{version}", shell_output("#{bin}/flyctl version")

    flyctl_status = shell_output("#{bin}/flyctl status 2>&1", 1)
    assert_match "Error: No access token available. Please login with 'flyctl auth login'", flyctl_status
  end
end
