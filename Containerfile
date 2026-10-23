FROM quay.io/fedora/fedora-minimal:44

ARG USER_NAME='devcon'
ARG USER_ID='1000'

ARG GROUP_NAME='devcon'
ARG GROUP_ID='1000'

ARG USER_HOME="/home/${USER_NAME}"
ARG VIBE_HOME="${USER_HOME}/.config/vibe"

RUN <<EOF
  set -euo pipefail

  # Install packages

  microdnf upgrade --assumeyes --setopt=install_weak_deps=0
  microdnf install --assumeyes --setopt=install_weak_deps=0 \
    bat \
    cargo-deny \
    ccache \
    clang \
    cmake \
    diff \
    fd-find \
    file \
    fish \
    git \
    glibc-all-langpacks \
    gnupg2 \
    golang \
    gzip \
    jq \
    lld \
    lldb \
    mesa-libGLU \
    postgresql \
    postgresql-devel \
    python \
    ripgrep \
    tar \
    tree \
    unzip \
    uv \
    vim \
    which \
    xz \
    zip
  microdnf clean all

  # Disable root account

  passwd --delete root
  usermod --expiredate 1 root

  # Set up user account

  mkdir --parents --verbose "${USER_HOME}"
  chown --recursive --verbose "${USER_ID}:${GROUP_ID}" "${USER_HOME}"
  groupadd --gid "${GROUP_ID}" "${GROUP_NAME}"
  useradd --uid "${USER_ID}" --gid "${GROUP_ID}" --home "${USER_HOME}" "${USER_NAME}"

  # Install code-server

  version="$(curl --silent --fail 'https://api.github.com/repos/coder/code-server/releases/latest' | jq --raw-output '.tag_name' | sed 's|^v||')"
  rpm --install --verbose "https://github.com/coder/code-server/releases/download/v${version}/code-server-${version}-amd64.rpm"

  for font in \
    'FiraCode-Medium' \
    'FiraCode-Light' \
    'FiraCode-SemiBold' \
    'FiraCode-Regular' \
    'SourceCodePro-BlackIt.otf' \
    'SourceCodePro-Black.otf' \
    'SourceCodePro-BoldIt.otf' \
    'SourceCodePro-Bold.otf' \
    'SourceCodePro-ExtraLightIt.otf' \
    'SourceCodePro-ExtraLight.otf' \
    'SourceCodePro-It.otf' \
    'SourceCodePro-LightIt.otf' \
    'SourceCodePro-Light.otf' \
    'SourceCodePro-MediumIt.otf' \
    'SourceCodePro-Medium.otf' \
    'SourceCodePro-Regular.otf' \
    'SourceCodePro-SemiboldIt.otf' \
    'SourceCodePro-Semibold.otf'
  do
    sed -i \
      "s|</head>|	<link rel=\"preload\" href=\"/static/out/media/fonts/${font}.woff2\" as=\"font\" type=\"font/woff2\" crossorigin=\"anonymous\">\n	</head>|g" \
      /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html
  done

  sed -i \
    's|</head>|	<link rel="stylesheet" type="text/css" href="/static/out/media/css/fonts.css">\n	</head>|g' \
    /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html

  extensions_dir='/usr/lib/code-server/lib/vscode/extensions'

  for extension in \
    'formulahendry.acp-client' \
    'google.arb-editor' \
    'golang.Go' \
    'llvm-vs-code-extensions.lldb-dap' \
    'llvm-vs-code-extensions.vscode-clangd' \
    'ms-python.debugpy' \
    'ms-python.python' \
    'ms-python.vscode-python-envs' \
    'ms-sarifvscode.sarif-viewer' \
    'ms-vscode.live-server' \
    'mtxr.sqltools' \
    'mtxr.sqltools-driver-pg' \
    'mtxr.sqltools-driver-sqlite' \
    'opentofu.vscode-opentofu' \
    'pkief.material-icon-theme' \
    'meta.pyrefly' \
    'redhat.vscode-yaml' \
    'rust-lang.rust-analyzer' \
    'santoso-wijaya.helios-selene' \
    'tombi-toml.tombi' \
    'vscode-icons-team.vscode-icons' \
    'vscodevim.vim'
  do
    code-server --extensions-dir "${extensions_dir}" --install-extension "${extension}"
  done

  chmod --recursive u=rwX,go=rX "${extensions_dir}"
  chown "${USER_NAME}:${GROUP_NAME}" "$(fd 'pkief.material-icon-theme' "${extensions_dir}")dist/material-icons.json"

  for extension in 'llvm-vs-code-extensions.lldb-dap' 'ms-python.debugpy'; do
    file="$(fd "${extension}" "${extensions_dir}").noConfigDebugAdapterEndpoints"
    touch "${file}"
    chown "${USER_NAME}:${GROUP_NAME}" "${file}"
  done

  rm --recursive '/root/.config/code-server'

  # Prepare tool directories

  mkdir --parent '/opt/flutter' '/opt/rust' '/opt/vibe/'{bin,uv}
  chown --recursive "${USER_NAME}:${USER_NAME}" '/opt/flutter'

  # Install Rust toolchain

  export GNUPGHOME="$(mktemp --directory)"
  gpg --batch --keyserver 'hkps://keyserver.ubuntu.com' --recv-keys '85AB96E6FA1BE5FE'
  gpg --batch --fingerprint '85AB96E6FA1BE5FE'
  version="$(curl --silent --fail 'https://api.github.com/repos/rust-lang/rust/releases/latest' | jq --raw-output '.tag_name' | sed 's|^v||')"

  url="https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.xz"
  echo "Retrieving ${url}.asc"
  curl --fail "${url}.asc" --output 'rust.tar.xz.asc'
  echo "Retrieving ${url}"
  curl --fail "${url}" --output 'rust.tar.xz'
  gpg --batch --verify 'rust.tar.xz.asc' 'rust.tar.xz'
  mkdir 'rust'
  tar --extract --strip-components 1 --file 'rust.tar.xz' --directory 'rust'
  rust/install.sh \
    --components='rustc,rust-std-x86_64-unknown-linux-gnu,cargo,rustfmt-preview,clippy-preview' \
    --prefix='/opt/rust'
  rm --recursive rust*

  url="https://static.rust-lang.org/dist/rust-src-${version}.tar.xz"
  echo "Retrieving ${url}.asc"
  curl --fail "${url}.asc" --output 'rust-src.tar.xz.asc'
  echo "Retrieving ${url}"
  curl --fail "${url}" --output 'rust-src.tar.xz'
  gpg --batch --verify 'rust-src.tar.xz.asc' 'rust-src.tar.xz'
  mkdir 'rust-src'
  tar --extract --strip-components 1 --file 'rust-src.tar.xz' --directory 'rust-src'
  rust-src/install.sh --prefix='/opt/rust'
  rm --recursive rust*

  rm --recursive "$GNUPGHOME"
  unset GNUPGHOME

  # Install Mistral Vibe

  vibe_install_log="/opt/vibe/install-log.txt"
  touch "${vibe_install_log}"

  UV_NO_MANAGED_PYTHON=1 \
  UV_PYTHON_DOWNLOADS=never \
  UV_NO_CACHE=1 \
  UV_TOOL_BIN_DIR='/opt/vibe/bin' \
  UV_TOOL_DIR='/opt/vibe/uv' \
  PATH="${PATH}:/opt/vibe/bin" \
    uv tool install "mistral-vibe>=2" 2>&1 | tee "${vibe_install_log}"
EOF

COPY 'code-server/fonts' '/usr/lib/code-server/lib/vscode/out/media/fonts/'
COPY 'code-server/css' '/usr/lib/code-server/lib/vscode/out/media/css/'
COPY 'bin' '/usr/local/bin/'

USER "${USER_NAME}"

ENV PATH="${PATH}:/opt/flutter/bin:/opt/rust/bin:/opt/vibe/bin:${USER_HOME}/.cargo/bin:${USER_HOME}/.local/bin" \
    HOME="${USER_HOME}" \
    VIBE_HOME="${VIBE_HOME}" \
    UV_NO_MANAGED_PYTHON=1 \
    UV_PYTHON_DOWNLOADS=never \
    UV_NO_CACHE=1

WORKDIR "${HOME}"

RUN <<EOF
  set -euo pipefail
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 '/opt/flutter'
  dart --disable-analytics
  flutter precache
  mkdir "${HOME}/.config/git"
EOF

COPY --chown="${USER_ID}:${GROUP_ID}" 'fish' "${HOME}/.config/fish/"
COPY --chown="${USER_ID}:${GROUP_ID}" 'code-server/config.yaml' "${HOME}/.config/code-server/"
COPY --chown="${USER_ID}:${GROUP_ID}" 'code-server/settings.json' "${HOME}/.local/share/code-server/User/"
COPY --chown="${USER_ID}:${GROUP_ID}" 'mistral-vibe/config.toml' "${VIBE_HOME}/"

LABEL io.containers.capabilities=""

ENTRYPOINT ["entrypoint"]

STOPSIGNAL SIGINT
