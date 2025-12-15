Name:           imtools
Version:        1.0.0
Release:        1%{?dist}
Summary:        Fast image manipulation CLI tool written in Zig

License:        MIT
URL:            https://github.com/4cecoder/imtools
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

# Zig is not in Fedora repos, must be installed manually
# BuildRequires:  zig >= 0.13

Recommends:     ffmpeg
Recommends:     curl
Suggests:       ollama

%description
A fast, standalone CLI tool for image and wallpaper management.

Features:
- Flatten nested image directories
- Find and remove duplicate images (SHA256)
- Delete portrait-oriented images
- Batch convert images to PNG (requires ffmpeg)
- Download wallpapers from wallhaven.cc
- AI-powered image sorting via Ollama

No runtime dependencies for core features.

%prep
%autosetup -n %{name}-%{version}

%build
zig build -Doptimize=ReleaseSafe

%install
install -Dm755 zig-out/bin/imtools %{buildroot}%{_bindir}/imtools
install -Dm644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dm644 README.md %{buildroot}%{_docdir}/%{name}/README.md
install -d %{buildroot}%{_docdir}/%{name}/docs
cp -r docs/* %{buildroot}%{_docdir}/%{name}/docs/

%files
%license LICENSE
%doc README.md docs/
%{_bindir}/imtools

%changelog
* Sun Dec 15 2024 4cecoder <4cecoder@users.noreply.github.com> - 1.0.0-1
- Initial package
