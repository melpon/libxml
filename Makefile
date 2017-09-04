ERL_INCLUDE_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
LIBXML2_VERSION = 2.9.4
LIBXML2_SHA256 = "958ae70baf186263a4bd801a81dd5d682aedd1db"

priv/libxml_nif.so: src/libxml_nif.c priv/libxml2/lib/libxml2.a
	cc -fPIC -I$(ERL_INCLUDE_PATH) -Ipriv/libxml2/include/libxml2 -lxml2 -dynamiclib -undefined dynamic_lookup -o $@ src/libxml_nif.c

priv/libxml2/lib/libxml2.a:
	@rm -rf libxml2_build
	mkdir -p libxml2_build
	cd libxml2_build \
		&& curl -LO http://xmlsoft.org/sources/libxml2-2.9.4.tar.gz \
		&& echo "$(LIBXML2_SHA256) *libxml2-2.9.4.tar.gz" | shasum -a 256 -c \
		&& tar xf libxml2-2.9.4.tar.gz \
		&& cd libxml2-2.9.4 \
		&& ./configure --prefix=`pwd`/../../priv/libxml2 --without-python \
		&& make -j2 \
		&& make install
	@rm -rf libxml2_build
