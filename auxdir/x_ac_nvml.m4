##*****************************************************************************
#  AUTHOR:
#    Michael Hinton <hinton@schedmd.com>
#
#  SYNOPSIS:
#    X_AC_NVML
#
#  DESCRIPTION:
#    Determine if NVIDIA's NVML API library exists (CUDA provides stubs)
##*****************************************************************************


AC_DEFUN([X_AC_NVML],
[
  func_check_path ()
  {
      AC_CHECK_HEADER([nvml.h], [ac_nvml_h=yes], [ac_nvml_h=no])
      AC_CHECK_LIB([nvidia-ml], [nvmlInit], [ac_nvml=yes], [ac_nvml=no])

      # Check indirectly that CUDA 11.1+ was installed to see if we
      # can build NVML MIG code. Do this by checking for the existence of
      # gpuInstanceSliceCount in the nvmlDeviceAttributes_t struct.
      AC_TRY_LINK([#include <nvml.h>],[nvmlDeviceAttributes_t attributes;
				       attributes.gpuInstanceSliceCount = 0;
				      ],
		  [ac_mig_support=yes], [ac_mig_support=no])
  }

  _x_ac_nvml_dirs="/usr/local/cuda /usr/cuda"
  _x_ac_nvml_libs="lib/stubs lib64/stubs"

  AC_ARG_WITH(
    [nvml],
    AS_HELP_STRING(--with-nvml=PATH, Specify path to CUDA installation),
    [AS_IF([test "x$with_nvml" != xno && test "x$with_nvml" != xyes],
           [_x_ac_nvml_dirs="$with_nvml"])])

  if [test "x$with_nvml" = xno]; then
     AC_MSG_WARN([support for nvml disabled])
  else

    # Check if libnvml is already in the system paths
    func_check_path

    if [ test "$ac_nvml" = "yes" && test "$ac_nvml_h" = "yes" ]; then
          # found in system path
          nvml_includes=""
          nvml_libs="-lnvidia-ml"
    else
      #try to find libnvml
      for d in $_x_ac_nvml_dirs; do
        if [ ! test -d "$d" ]; then
          continue
        fi
        for bit in $_x_ac_nvml_libs; do
          if [ ! test -d "$d/$bit" || ! test -d "$d/include" ]; then
            continue
          fi
          _x_ac_nvml_ldflags_save="$LDFLAGS"
          _x_ac_nvml_cppflags_save="$CPPFLAGS"
          LDFLAGS="-L$d/$bit -lnvidia-ml"
          CPPFLAGS="-I$d/include $CPPFLAGS"
          $as_unset ac_cv_header_nvml_h
          $as_unset ac_cv_lib_nvidia_ml_nvmlInit
          $as_unset ac_cv_lib_nvidia_ml_nvmlVgpuTypeGetGpuInstanceProfileId

          func_check_path

          LDFLAGS="$_x_ac_nvml_ldflags_save"
          CPPFLAGS="$_x_ac_nvml_cppflags_save"
          if [ test "$ac_nvml" = "yes" && test "$ac_nvml_h" = "yes" ]; then
            nvml_includes="-I$d/include"
            nvml_libs="-L$d/$bit -lnvidia-ml"
            break
          fi
        done
        if [ test "$ac_nvml" = "yes" && test "$ac_nvml_h" = "yes" ]; then
          break
        fi
      done
    fi

    if [ test "$ac_mig_support" = "yes" ]; then
	    AC_DEFINE(HAVE_MIG_SUPPORT, 1, [Define to 1 if NVML library has MIG support])
    else
	    AC_MSG_WARN([For MIG support both nvml.h and libnvidia-ml must be 11.1+. Please make sure they are both the same version as well. Can not support MIG.])
    fi

    if [ test "$ac_nvml" = "yes" && test "$ac_nvml_h" = "yes" ]; then
      NVML_LIBS="$nvml_libs"
      NVML_CPPFLAGS="$nvml_includes"
      AC_DEFINE(HAVE_NVML, 1, [Define to 1 if NVML library found])
    else
      if test -z "$with_nvml"; then
        AC_MSG_WARN([unable to locate libnvidia-ml.so and/or nvml.h])
      else
        AC_MSG_ERROR([unable to locate libnvidia-ml.so and/or nvml.h])
      fi
    fi

    AC_SUBST(NVML_LIBS)
    AC_SUBST(NVML_CPPFLAGS)
  fi
  AM_CONDITIONAL(BUILD_NVML, test "$ac_nvml" = "yes" && test "$ac_nvml_h" = "yes")
])
