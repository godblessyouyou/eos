	OS_VER=$( grep VERSION_ID /etc/os-release | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' | cut -d'.' -f1 )

	MEM_MEG=$( free -m | grep Mem | tr -s ' ' | cut -d\  -f2 )
	CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
	CPU_CORE=$( lscpu | grep "^CPU(s)" | tr -s ' ' | cut -d\  -f2 )
	MEM_GIG=$(( ((MEM_MEG / 1000) / 2) ))
	export JOBS=$(( MEM_GIG > CPU_CORE ? CPU_CORE : MEM_GIG ))

	DISK_TOTAL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f2 | sed 's/[^0-9]//' )
	DISK_AVAIL=$( df -h . | grep /dev | tr -s ' ' | cut -d\  -f4 | sed 's/[^0-9]//' )

	printf "\\n\\tOS name: %s\\n" "${OS_NAME}"
	printf "\\tOS Version: %s\\n" "${OS_VER}"
	printf "\\tCPU speed: %sMhz\\n" "${CPU_SPEED}"
	printf "\\tCPU cores: %s\\n" "$CPU_CORE"
	printf "\\tPhysical Memory: %s Mgb\\n" "${MEM_MEG}"
	printf "\\tDisk space total: %sGb\\n" "${DISK_TOTAL}"
	printf "\\tDisk space available: %sG\\n" "${DISK_AVAIL}"

	if [ "$MEM_MEG" -lt 7000 ]; then
		printf "\\tYour system must have 7 or more Gigabytes of physical memory installed.\\n"
		printf "\\texiting now.\\n"
		exit 1
	fi

	if [ "$OS_VER" -lt 2017 ]; then
		printf "\\tYou must be running Amazon Linux 2017.09 or higher to install EOSIO.\\n"
		printf "\\texiting now.\\n"
		exit 1
	fi

	if [ "$DISK_AVAIL" -lt "$DISK_MIN" ]; then
		printf "\\tYou must have at least %sGB of available storage to install EOSIO.\\n" "${DISK_MIN}"
		printf "\\texiting now.\\n"
		exit 1
	fi

	printf "\\n\\tChecking Yum installation.\\n"
	if ! YUM=$( command -v yum 2>/dev/null )
	then
		printf "\\n\\tYum must be installed to compile EOS.IO.\\n"
		printf "\\n\\tExiting now.\\n"
		exit 1
	fi
	
	printf "\\tYum installation found at %s.\\n" "${YUM}"
	printf "\\tUpdating YUM.\\n"
	if ! UPDATE=$( sudo "$YUM" -y update )
	then
		printf "\\n\\tYUM update failed.\\n"
		printf "\\n\\tExiting now.\\n"
		exit 1
	fi
	printf "\\t%s\\n" "${UPDATE}"

	DEP_ARRAY=( git gcc72.x86_64 gcc72-c++.x86_64 autoconf automake libtool make bzip2 \
	bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 libstdc++72.x86_64 \
	python27.x86_64 python36-devel.x86_64 libedit-devel.x86_64 doxygen.x86_64 graphviz.x86_64)
	COUNT=1
	DISPLAY=""
	DEP=""

	printf "\\n\\tChecking YUM for installed dependencies.\\n\\n"

	for (( i=0; i<${#DEP_ARRAY[@]}; i++ ));
	do
		pkg=$( sudo "$YUM" info "${DEP_ARRAY[$i]}" 2>/dev/null | grep Repo | tr -s ' ' | cut -d: -f2 | sed 's/ //g' )

		if [ "$pkg" != "installed" ]; then
			DEP=$DEP" ${DEP_ARRAY[$i]} "
			DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\\n\\t"
			printf "\\tPackage %s ${bldred} NOT ${txtrst} found.\\n" "${DEP_ARRAY[$i]}"
			(( COUNT++ ))
		else
			printf "\\tPackage %s found.\\n" "${DEP_ARRAY[$i]}"
			continue
		fi
	done		

	if [ "${COUNT}" -gt 1 ]; then
		printf "\\n\\tThe following dependencies are required to install EOSIO.\\n"
		printf "\\n\\t%s\\n\\n" "$DISPLAY"
		printf "\\tDo you wish to install these dependencies?\\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* ) 
					printf "\\n\\n\\tInstalling dependencies.\\n\\n"
					if ! sudo "${YUM}" -y install ${DEP}
					then
						printf "\\n\\tYUM dependency installation failed.\\n"
						printf "\\n\\tExiting now.\\n"
						exit 1
					else
						printf "\\n\\tYUM dependencies installed successfully.\\n"
					fi
				break;;
				[Nn]* ) printf "\\nUser aborting installation of required dependencies,\\n Exiting now.\\n"; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else 
		printf "\\n\\tNo required YUM dependencies to install.\\n"
	fi

	if [[ "$ENABLE_CODE_COVERAGE" == true ]]; then
		printf "\\n\\tChecking perl installation.\\n"
		if ! perl_bin=$( command -v perl 2>/dev/null )
		then
			printf "\\n\\tInstalling perl.\\n"
			if ! sudo "${YUM}" -y install perl
			then
				printf "\\n\\tUnable to install perl at this time.\\n"
				printf "\\n\\tExiting now.\\n"
				exit 1
			fi
		else
			printf "\\n\\tPerl installation found at %s.\\n" "${perl_bin}"
		fi
		printf "\\n\\tChecking LCOV installation.\\n"
		if [ ! -e "/usr/local/bin/lcov" ]; then
			printf "\\n\\tLCOV installation not found.\\n"
			printf "\\tInstalling LCOV.\\n"
			if ! cd "${TEMP_DIR}"
			then
				printf "\\n\\tUnable to enter %s. Exiting now.\\n" "${TEMP_DIR}"; 
				exit 1;
			fi
			if ! git clone "https://github.com/linux-test-project/lcov.git"
			then
				printf "\\n\\tUnable to clone LCOV at this time.\\n"
				printf "\\tExiting now.\\n\\n"
				exit 1;
			fi
			if ! cd "${TEMP_DIR}/lcov"
			then
				printf "\\n\\tUnable to enter %s. Exiting now.\\n" "${TEMP_DIR}/lcov"; 
				exit 1;
			fi
			if ! sudo make install
			then
				printf "\\n\\tUnable to install LCOV at this time.\\n"
				printf "\\tExiting now.\\n\\n"
				exit 1;
			fi
			rm -rf "${TEMP_DIR}/lcov"
			printf "\\n\\tSuccessfully installed LCOV.\\n\\n"
		else
			printf "\\n\\tLCOV installation found @ /usr/local/bin/lcov.\\n"
		fi
	fi

	printf "\\n\\tChecking CMAKE installation.\\n"
    if [ ! -e "${CMAKE}" ]; then
		printf "\\tInstalling CMAKE.\\n"
		if ! mkdir -p "${HOME}/opt/" 2>/dev/null
		then
			printf "\\n\\tUnable to create directory %s at this time.\\n" "${HOME}/opt/"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${HOME}/opt"
		then
			printf "\\n\\tUnable to change directory into %s at this time.\\n" "${HOME}/opt/"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		STATUS=$( curl -LO -w '%{http_code}' --connect-timeout 30 "https://cmake.org/files/v3.10/cmake-3.10.2.tar.gz" )
		if [ "${STATUS}" -ne 200 ]; then
			printf "\\tUnable to download CMAKE at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf "cmake-3.10.2.tar.gz"
		then
			printf "\\tUnable to decompress file cmake-3.10.2.tar.gz at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -f cmake-3.10.2.tar.gz
		then
			printf "\\tUnable to remove file cmake-3.10.2.tar.gz at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! ln -s "${HOME}/opt/cmake-3.10.2/" "${HOME}/opt/cmake"
		then
			printf "\\tUnable to symlink directory %s to %s at this time.\\n" "${HOME}/opt/cmake-3.10.2/" "${HOME}/opt/cmake"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${HOME}/opt/cmake/"
		then
			printf "\\n\\tUnable to change directory into %s at this time.\\n" "${HOME}/opt/cmake"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! ./bootstrap
		then
			printf "\\tError running bootstrap for CMAKE.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! make -j${JOBS}
		then
			printf "\\tError compiling CMAKE.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
	else
		printf "\\tCMAKE found @ %s.\\n" "${CMAKE}"
	fi

	printf "\\n\\tChecking boost library installation.\\n"
	BVERSION=$( grep "BOOST_LIB_VERSION" "${BOOST_ROOT}/include/boost/version.hpp" 2>/dev/null \
	| tail -1 | tr -s ' ' | cut -d\  -f3 | sed 's/[^0-9\._]//gI' )
	if [ "${BVERSION}" != "1_66" ]; then
		printf "\\tRemoving existing boost libraries in %s.\\n" "${HOME}/opt/boost*"
		if ! rm -rf "${HOME}/opt/boost*"
		then
			printf "\\n\\tUnable to remove deprecated boost libraries at this time.\\n"
			printf "\\n\\tExiting now.\\n"
			exit 1
		fi
		printf "\\tInstalling boost libraries.\\n"
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s at this time.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1
		fi
		STATUS=$(curl -LO -w '%{http_code}' --connect-timeout 30 \
		"https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.bz2" )
		if [ "${STATUS}" -ne 200 ]; then
			printf "\\tUnable to download Boost libraries at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf "${TEMP_DIR}/boost_1_66_0.tar.bz2"
		then
			printf "\\tUnable to decompress Boost libraries @ %s at this time.\\n" "${TEMP_DIR}/boost_1_66_0.tar.bz2"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -f  "${TEMP_DIR}/boost_1_66_0.tar.bz2"
		then
			printf "\\tUnable to remove Boost libraries @ %s at this time.\\n" "${TEMP_DIR}/boost_1_66_0.tar.bz2"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/boost_1_66_0/"
		then
			printf "\\tUnable to change directory into %s at this time.\\n" "${TEMP_DIR}/boost_1_66_0/"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! ./bootstrap.sh "--prefix=$BOOST_ROOT"
		then
			printf "\\n\\tInstallation of boost libraries failed. 0\\n"
			printf "\\n\\tExiting now.\\n"
			exit 1
		fi
		if ! ./b2 install
		then
			printf "\\n\\tInstallation of boost libraries failed. 1\\n"
			printf "\\n\\tExiting now.\\n"
			exit 1
		fi
		if ! rm -rf "${TEMP_DIR}/boost_1_66_0/"
		then
			printf "\\n\\tUnable to remove boost libraries directory @ %s.\\n" "${TEMP_DIR}/boost_1_66_0/"
			printf "\\n\\tExiting now.\\n"
			exit 1
		fi
	else
		printf "\\tBoost 1.66.0 found at %s.\\n" "${HOME}/opt/boost_1_66_0"
	fi

	printf "\\n\\tChecking MongoDB installation.\\n"
	if [ ! -e "${MONGOD_CONF}" ]; then
		printf "\\tInstalling MongoDB 3.6.3.\\n"
		if ! cd "${HOME}/opt"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${HOME}/opt"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		STATUS=$( curl -LO -w '%{http_code}' --connect-timeout 30 \
		"https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.6.3.tgz" )
		if [ "${STATUS}" -ne 200 ]; then
			printf "\\tUnable to download MongoDB at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf "${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3.tgz"
		then
			printf "\\tUnable to decompress file %s at this time.\\n" \
			"${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3.tgz"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -f "${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3.tgz"
		then
			printf "\\tUnable to remove file %s at this time.\\n" "${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3.tgz"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! ln -s "${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3/" "${HOME}/opt/mongodb"
		then
			printf "\\tUnable to symlink directory %s to directory at this time.\\n" \
			"${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3/" "${HOME}/opt/mongodb"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! mkdir "${HOME}/opt/mongodb/data"
		then
			printf "\\tUnable to make directory %s at this time.\\n" "${HOME}/opt/mongodb/data"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! mkdir "${HOME}/opt/mongodb/log"
		then
			printf "\\tUnable to make directory %s at this time.\\n" "${HOME}/opt/mongodb/log"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! touch "${HOME}/opt/mongodb/log/mongodb.log"
		then
			printf "\\tUnable to create log file @ %s at this time.\\n" "${HOME}/opt/mongodb/log/mongodb.log"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		
if ! tee > "/dev/null" "${MONGOD_CONF}" <<mongodconf
systemLog:
 destination: file
 path: ${HOME}/opt/mongodb/log/mongodb.log
 logAppend: true
 logRotate: reopen
net:
 bindIp: 127.0.0.1,::1
 ipv6: true
storage:
 dbPath: ${HOME}/opt/mongodb/data
mongodconf
then
	printf "\\tUnable to create mongodb config file @ %s at this time.\\n" "${HOME}/opt/mongodb/log/mongodb.log"
	printf "\\tExiting now.\\n\\n"
	exit 1;
fi
		printf "\\n\\n\\tMongoDB successfully installed.\\n\\tConfiguration file @ %s.\\n\\n" "${MONGOD_CONF}"

	else
		printf "\\tMongoDB configuration found at %s.\\n" "${MONGOD_CONF}"
	fi

	printf "\\n\\tChecking MongoDB C++ driver installation.\\n"
	if [ ! -e "/usr/local/lib/libmongocxx-static.a" ]; then
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		STATUS=$(curl -LO -w '%{http_code}' --connect-timeout 30 \
		"https://github.com/mongodb/mongo-c-driver/releases/download/1.9.3/mongo-c-driver-1.9.3.tar.gz" )
		if [ "${STATUS}" -ne 200 ]; then
			rm -f "${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz"
			printf "\\tUnable to download MongoDB C driver at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! tar xf "${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz"
		then
			printf "\\n\\tUnable to decompress file  %s.\\n" "${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! rm -f "${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz"
		then
			printf "\\n\\tUnable to remove file  %s.\\n" "${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/mongo-c-driver-1.9.3"
		then
			printf "\\n\\tUnable to change directory info  %s.\\n" "${TEMP_DIR}/mongo-c-driver-1.9.3"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! ./configure --enable-static --with-libbson=bundled --enable-ssl=openssl --disable-automatic-init-and-cleanup --prefix=/usr/local
		then
			printf "\\tConfiguring MongoDB C driver has encountered the errors above.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! make -j${JOBS}
		then
			printf "\\tError compiling MongoDB C driver.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make install
		then
			printf "\\tError installing MongoDB C driver.\\nMake sure you have sudo privileges.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/mongo-c-driver-1.9.3"
		then
			printf "\\n\\tUnable to remove  directory %s.\\n" "${TEMP_DIR}/mongo-c-driver-1.9.3"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! git clone https://github.com/mongodb/mongo-cxx-driver.git --branch releases/stable --depth 1
		then
			printf "\\tUnable to clone MongoDB C++ driver at this time.\\n"
			printf "\\tExiting now.\\n\\n"
			exit;
		fi
		if ! cd "${TEMP_DIR}/mongo-cxx-driver/build"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}/mongo-cxx-driver/build"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		
		if ! "${CMAKE}" -DBUILD_SHARED_LIBS="OFF" -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_PREFIX="/usr/local" "${TEMP_DIR}/mongo-cxx-driver"
		then
			printf "\\tCmake has encountered the above errors building the MongoDB C++ driver.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make -j"${JOBS}"
		then
			printf "\\tError compiling MongoDB C++ driver.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make install
		then
			printf "\\tError installing MongoDB C++ driver.\\nMake sure you have sudo privileges.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! sudo rm -rf "${TEMP_DIR}/mongo-cxx-driver"
		then
			printf "\\n\\tUnable to remove directory %s.\\n" "${TEMP_DIR}" "${TEMP_DIR}/mongo-cxx-driver"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		printf "\\tSuccessfully installed Mongo C/C++ drivers found at /usr/local/lib/libmongocxx-static.a.\\n"
	else
		printf "\\tMongo C++ driver found at /usr/local/lib/libmongocxx-static.a.\\n"
	fi

	printf "\\n\\tChecking secp256k1-zkp installation.\\n"
    # install secp256k1-zkp (Cryptonomex branch)
    if [ ! -e "/usr/local/lib/libsecp256k1.a" ]; then
		printf "\\tInstalling secp256k1-zkp (Cryptonomex branch).\\n"
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! git clone https://github.com/cryptonomex/secp256k1-zkp.git
		then
			printf "\\tUnable to clone repo secp256k1-zkp @ https://github.com/cryptonomex/secp256k1-zkp.git.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/secp256k1-zkp"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}/secp256k1-zkp"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! ./autogen.sh
		then
			printf "\\tError running autogen for secp256k1-zkp.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! ./configure
		then
			printf "\\tError running configure for secp256k1-zkp.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! make -j"${JOBS}"
		then
			printf "\\tError compiling secp256k1-zkp.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! sudo make install
		then
			printf "\\tError installing secp256k1-zkp.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/secp256k1-zkp"
		then
			printf "\\tError removing directory %s.\\n" "${TEMP_DIR}/secp256k1-zkp"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		printf "\\tsecp256k1 successfully installed @ /usr/local/lib/libsecp256k1.a.\\n"
	else
		printf "\\tsecp256k1 found @ /usr/local/lib/libsecp256k1.a.\\n"
	fi

	printf "\\n\\tChecking LLVM with WASM support.\\n"
	if [ ! -d "${HOME}/opt/wasm/bin" ]; then
		printf "\\tInstalling LLVM & WASM.\\n"
		if ! cd "${TEMP_DIR}"
		then
			printf "\\n\\tUnable to cd into directory %s.\\n" "${TEMP_DIR}"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/llvm-compiler"  2>/dev/null
		then
			printf "\\n\\tUnable to make directory %s.\\n" "${TEMP_DIR}/llvm-compiler"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler"
		then
			printf "\\n\\tUnable to change directory into %s.\\n" "${TEMP_DIR}/llvm-compiler"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/llvm.git
		then
			printf "\\tUnable to clone llvm repo @ https://github.com/llvm-mirror/llvm.git.\\n"
			printf "\\tExiting now.\\n\\n"
			exit;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm/tools"
		then
			printf "\\n\\tUnable to change directory into %s.\\n" "${TEMP_DIR}/llvm-compiler/llvm/tools"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/clang.git
		then
			printf "\\tUnable to clone clang repo @ https://github.com/llvm-mirror/clang.git.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm"
		then
			printf "\\n\\tUnable to change directory into %s.\\n" "${TEMP_DIR}/llvm-compiler/llvm"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! mkdir "${TEMP_DIR}/llvm-compiler/llvm/build" 2>/dev/null
		then
			printf "\\n\\tUnable to create directory %s.\\n" "${TEMP_DIR}/llvm-compiler/llvm/build"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! cd "${TEMP_DIR}/llvm-compiler/llvm/build"
		then
			printf "\\n\\tUnable to change directory into %s.\\n" "${TEMP_DIR}/llvm-compiler/llvm/build"
			printf "\\n\\tExiting now.\\n"
			exit 1;
		fi
		if ! "$CMAKE" -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${HOME}/opt/wasm" \
		-DLLVM_ENABLE_RTTI=1 -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="WebAssembly" \
		-DCMAKE_BUILD_TYPE="Release" ..
		then
			printf "\\tError compiling LLVM and clang with EXPERIMENTAL WASM support.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! make -j"${JOBS}"
		then
			printf "\\tError compiling LLVM and clang with EXPERIMENTAL WASM support.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! make install
		then
			printf "\\tError installing LLVM and clang with EXPERIMENTAL WASM support.\\n"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		if ! rm -rf "${TEMP_DIR}/llvm-compiler" 2>/dev/null
		then
			printf "\\tError removing directory %s.\\n" "${TEMP_DIR}/llvm-compiler"
			printf "\\tExiting now.\\n\\n"
			exit 1;
		fi
		printf "\\tWASM successfully installed at %s.\\n" "${HOME}/opt/wasm"
	else
		printf "\\tWASM found at %s.\\n" "${HOME}/opt/wasm"
	fi

	function print_instructions()
	{
		printf "\\n\\t%s -f %s &\\n" "$( command -v mongod )" "${MONGOD_CONF}"
		printf '\texport PATH=${HOME}/opt/mongodb/bin:$PATH \n'
		printf "\\tcd %s; make test\\n\\n" "${BUILD_DIR}"
	return 0
	}