# Homebrew formula for imtools
# Install: brew install --build-from-source ./imtools.rb
# Or submit to homebrew-core / create a tap

class Imtools < Formula
  desc "Fast image manipulation CLI tool written in Zig"
  homepage "https://github.com/4cecoder/imtools"
  url "https://github.com/4cecoder/imtools/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  head "https://github.com/4cecoder/imtools.git", branch: "main"

  depends_on "zig" => :build

  # Optional runtime dependencies
  uses_from_macos "curl"

  def install
    system "zig", "build", "-Doptimize=ReleaseSafe"
    bin.install "zig-out/bin/imtools"
    doc.install "README.md", "LICENSE"
    doc.install Dir["docs/*"]
  end

  def caveats
    <<~EOS
      Optional dependencies for full functionality:
        brew install ffmpeg   # for convert-to-png and download commands
        brew install ollama   # for AI-powered sort command

      To use the AI sorting feature:
        ollama serve &
        ollama pull moondream:1.8b
        imtools sort --help
    EOS
  end

  test do
    # Test help command
    assert_match "imtools", shell_output("#{bin}/imtools help")

    # Test flatten dry-run on empty directory
    mkdir "test_dir"
    cd "test_dir" do
      system "#{bin}/imtools", "flatten", "--dry-run"
    end
  end
end
