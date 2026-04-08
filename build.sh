source /dev/stdin <<< "$(curl -s https://raw.githubusercontent.com/pytgcalls/build-toolkit/refs/heads/master/build-toolkit.sh)"

require xcode
require venv

import patch-meson.sh
import libraries.properties
import meson from python3
if ! is_windows; then
  import ninja from python3
fi

windows_args="/O2 /Ob1 /Oy- /Zi /FS /GF /GS /Gy /DNDEBUG /fp:precise /Zc:wchar_t /Zc:forScope /D_VARIADIC_MAX=10"
windows_x86_args="/O2 /Ob1 /Oy- /Zi /FS /GF /GS /Gy /DNDEBUG /fp:precise /Zc:wchar_t /Zc:forScope /D_VARIADIC_MAX=10 /arch:IA32"

setup_msvc_target() {
  local target_arch="${OPENH264_WINDOWS_ARCH:-x86_64}"
  local msvc_target_arch=""
  local machine_flag=""
  local expected_machine=""

  case "$target_arch" in
    x86)
      msvc_target_arch="x86"
      machine_flag="/MACHINE:X86"
      expected_machine="x86"
      ;;
    x86_64)
      msvc_target_arch="x64"
      machine_flag="/MACHINE:X64"
      expected_machine="x64"
      ;;
    *)
      echo "[error] Unsupported OPENH264_WINDOWS_ARCH: $target_arch" >&2
      exit 1
      ;;
  esac

  VS_EDITION="$(get_vs_edition "$VS_BASE_PATH")"
  MSVC_VERSION="$(get_msvc_version "$VS_BASE_PATH" "$VS_EDITION")"
  WINDOWS_KITS_VERSION="$(get_windows_kits_version "$WINDOWS_KITS_BASE_PATH")"

  MSVC_ROOT="$VS_BASE_PATH/$VS_EDITION/VC/Tools/MSVC/$MSVC_VERSION"
  append_env_path "PATH" "$MSVC_ROOT/bin/Hostx64/$msvc_target_arch"
  append_env_path "LIB" "$MSVC_ROOT/lib/$msvc_target_arch"
  append_env_path "LIB" "$WINDOWS_KITS_BASE_PATH/Lib/$WINDOWS_KITS_VERSION/um/$msvc_target_arch"
  append_env_path "LIB" "$WINDOWS_KITS_BASE_PATH/Lib/$WINDOWS_KITS_VERSION/ucrt/$msvc_target_arch"
  append_env_path "INCLUDE" "$MSVC_ROOT/include"
  append_env_path "INCLUDE" "$WINDOWS_KITS_BASE_PATH/Include/$WINDOWS_KITS_VERSION/ucrt"
  append_env_path "INCLUDE" "$WINDOWS_KITS_BASE_PATH/Include/$WINDOWS_KITS_VERSION/um"
  append_env_path "INCLUDE" "$WINDOWS_KITS_BASE_PATH/Include/$WINDOWS_KITS_VERSION/shared"
  append_env_path "INCLUDE" "$WINDOWS_KITS_BASE_PATH/Include/$WINDOWS_KITS_VERSION/winrt"
  append_env_path "INCLUDE" "$WINDOWS_KITS_BASE_PATH/Include/$WINDOWS_KITS_VERSION/cppwinrt"

  export OPENH264_MACHINE_FLAG="$machine_flag"
  export OPENH264_EXPECTED_MACHINE="$expected_machine"
}

verify_windows_artifact_arch() {
  local lib_path="artifacts/lib/openh264.lib"
  if [[ ! -f "$lib_path" ]]; then
    echo "[error] Missing expected library: $lib_path" >&2
    exit 1
  fi

  local dump_out
  dump_out="$(dumpbin /headers "$(to_windows "$lib_path")" 2>/dev/null)"

  if [[ "$OPENH264_EXPECTED_MACHINE" == "x86" ]]; then
    echo "$dump_out" | grep -qi "machine (x86)" || {
      echo "[error] openh264.lib is not 32-bit x86" >&2
      exit 1
    }
    if echo "$dump_out" | grep -qi "machine (x64)"; then
      echo "[error] x64 objects detected in x86 build output" >&2
      exit 1
    fi
  else
    echo "$dump_out" | grep -qi "machine (x64)" || {
      echo "[error] openh264.lib is not x64 for windows_x86_64 build" >&2
      exit 1
    }
  fi
}

if ! is_windows; then
  echo "[error] This repository is configured to build only Windows targets in CI." >&2
  exit 1
fi

setup_msvc_target

if [[ "${OPENH264_WINDOWS_ARCH:-x86_64}" == "x86" ]]; then
  build_and_install "openh264" meson-static \
    -Dtests=disabled \
    --windows="-Db_vscrt=mt -Dc_args='$windows_x86_args' -Dcpp_args='$windows_x86_args' -Dc_link_args='$OPENH264_MACHINE_FLAG' -Dcpp_link_args='$OPENH264_MACHINE_FLAG'" \
    --setup-commands="patch_meson"
else
  build_and_install "openh264" meson-static \
    -Dtests=disabled \
    --windows="-Db_vscrt=mt -Dc_args='$windows_args' -Dcpp_args='$windows_args' -Dc_link_args='$OPENH264_MACHINE_FLAG' -Dcpp_link_args='$OPENH264_MACHINE_FLAG'" \
    --setup-commands="patch_meson"
fi

copy_libs "openh264" "artifacts"
verify_windows_artifact_arch
