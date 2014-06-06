# check whether libcrypto.a already exists - we'll only build if it does not
if [ -f  "$TARGET_BUILD_DIR/libssl.a" ]; then
	echo "Using previously-built libary $TARGET_BUILD_DIR/libssl.a - skipping build"
	echo "To force a rebuild clean project and clean dependencies"
	exit 0;
fi

# figure out the right set of build architectures for this run
BUILDARCHS="$ARCHS"

echo "***** creating universal binary for architectures: $BUILDARCHS *****"

if [ "$SDKROOT" != "" ]; then
	ISYSROOT="-isysroot $SDKROOT"
fi

OPENSSL_OPTIONS="no-krb5 no-gost"

cd "$SRCROOT/openssl"

for BUILDARCH in $BUILDARCHS
do

	echo "Building for architecture $BUILDARCH"

	make clean > /dev/null

	# disable assembler
	echo "***** configuring WITHOUT assembler optimizations based on architecture $BUILDARCH and build style $BUILD_STYLE *****"
	./config no-asm $OPENSSL_OPTIONS > /dev/null
	ASM_DEF="-UOPENSSL_BN_ASM_PART_WORDS"

	make CFLAG="-D_DARWIN_C_SOURCE $ASM_DEF -arch $BUILDARCH $ISYSROOT -Wno-unused-value -Wno-parentheses" SHARED_LDFLAGS="-arch $BUILDARCH -dynamiclib" > /dev/null

	echo "***** copying intermediate libraries to $CONFIGURATION_TEMP_DIR/$BUILDARCH-*.a *****"
	cp libcrypto.a "$CONFIGURATION_TEMP_DIR"/$BUILDARCH-libcrypto.a
	cp libssl.a "$CONFIGURATION_TEMP_DIR"/$BUILDARCH-libssl.a
done

make clean > /dev/null

echo "***** creating universallibraries in $TARGET_BUILD_DIR *****"
mkdir -p "$TARGET_BUILD_DIR"
lipo -create "$CONFIGURATION_TEMP_DIR/"*-libcrypto.a -output "$TARGET_BUILD_DIR/libcrypto.a"
lipo -create "$CONFIGURATION_TEMP_DIR/"*-libssl.a -output "$TARGET_BUILD_DIR/libssl.a"

echo "***** removing temporary files from $CONFIGURATION_TEMP_DIR *****"
rm -f "$CONFIGURATION_TEMP_DIR/"*-libcrypto.a
rm -f "$CONFIGURATION_TEMP_DIR/"*-libssl.a

echo "***** executing ranlib on libraries in $TARGET_BUILD_DIR *****"
ranlib "$TARGET_BUILD_DIR/libcrypto.a"
ranlib "$TARGET_BUILD_DIR/libssl.a"
                                       
