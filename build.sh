function libHasArchs() {
	LIB=$1

	if [ ! -f "$LIB" ]
	then
		return 1
	fi
	
	LIPOINFO=`xcrun lipo -info "$LIB"`

	for ARCH in $ARCHS
	do
		if [[ $LIPOINFO != *"$ARCH"* ]]
		then		
			return 1
		fi
	done

	return 0
}

REBUILDSTRING="To force a rebuild do a full project clean"
LIBSSLPATH="${TARGET_BUILD_DIR}/libssl.a"
LIBCRYPTOPATH="${TARGET_BUILD_DIR}/libcrypto.a"

if libHasArchs "$LIBCRYPTOPATH" && libHasArchs "$LIBSSLPATH"
then
  echo "Using existing builds for libssl.a and libcrypto.a"
  echo "$REBUILDSTRING"
  exit 0
fi

echo "Building for architectures: $ARCHS"

if [ "$SDKROOT" != "" ]; then
	isysroot="-isysroot ${SDKROOT}"
fi

ASM_DEF="-UOPENSSL_BN_ASM_PART_WORDS"
LIBOUTPUTPATH="${TARGET_TEMP_DIR}"
LOGPATH="${TARGET_TEMP_DIR}/build.log"
rm -rf $LOGPATH

cd "${SRCROOT}/openssl"

for ARCH in $ARCHS
do
  
  LIBSSLARCHPATH="${LIBOUTPUTPATH}/$ARCH-libssl.a"  
  LIBCRYPTOARCHPATH="${LIBOUTPUTPATH}/$ARCH-libcrypto.a"
  
  if libHasArchs "$LIBSSLARCHPATH" && libHasArchs "$LIBCRYPTOARCHPATH"
  then
    echo "Using existing build for architecture: $ARCH"
    echo "$REBUILDSTRING"
    continue
  fi
  
	echo "Building for architecture: $ARCH"
  
  configureTarget="iphoneos-cross"
  if [ "$ARCH" == "i386" ]; then
    configureTarget="darwin-i386-cc"
  elif [ "$ARCH" == "x86_64" ]; then
    configureTarget="darwin64-x86_64-cc"
  fi

  configureOptions="$configureTarget"
  archFlag="-arch $ARCH"

  echo "Configure with options: $configureOptions"
  ./Configure $configureOptions &> $LOGPATH

  make clean &> $LOGPATH
  
  makeOptions="CFLAG=\"-D_DARWIN_C_SOURCE $archFlag $isysroot\" SHARED_LDFLAGS=\"$archFlag -Os\""
  echo "Make with options: $makeOptions" 
  make CFLAG="-D_DARWIN_C_SOURCE $archFlag $isysroot" SHARED_LDFLAGS="$archFlag -Os" &> $LOGPATH

  echo "Copy libssl.a to ${LIBSSLARCHPATH}"
  cp libssl.a "${LIBSSLARCHPATH}" &> $LOGPATH

  echo "Copy libcrypto.a to ${LIBCRYPTOARCHPATH}"
  cp libcrypto.a "${LIBCRYPTOARCHPATH}" &> $LOGPATH

  make clean &> $LOGPATH
done

echo "Lipo"
mkdir -p "${TARGET_BUILD_DIR}"
lipo -create "${LIBOUTPUTPATH}/"*-libssl.a -output "$LIBSSLPATH" &> $LOGPATH
lipo -create "${LIBOUTPUTPATH}/"*-libcrypto.a -output "$LIBCRYPTOPATH" &> $LOGPATH

echo "Ranlib"
ranlib "$LIBSSLPATH" &> $LOGPATH
ranlib "$LIBCRYPTOPATH" &> $LOGPATH
