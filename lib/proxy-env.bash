if [[ '0' != "${DEVCON_USE_PROXY:-0}" ]]; then
  export NO_PROXY='localhost,127.0.0.1,::1'
  export HTTP_PROXY='http://127.0.0.1:8888'
  export HTTPS_PROXY="${HTTP_PROXY}"
fi
