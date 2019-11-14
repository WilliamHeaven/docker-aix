git clone git://git.qemu.org/qemu.git
cd qemu 
mkdir build
cd build
../configure
make
su 
make install 
exit 
qemu-system-ppc64 --version
