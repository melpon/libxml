ERL_INCLUDE_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
LIBXML2_VERSION = 2.9.4
LIBXML2_SHA256 = "ffb911191e509b966deb55de705387f14156e1a56b21824357cdf0053233633c"
SHASUM = $(shell if which shasum > /dev/null 2>&1; then echo "shasum -a 256"; else echo "sha256sum"; fi)
CURL = $(shell if which curl > /dev/null 2>&1; then echo "curl -LO"; else echo "wget"; fi)
DARWIN_LDFLAGS = $(shell if [ "`uname`" == "Darwin" ]; then echo "-undefined dynamic_lookup"; else echo ""; fi)

priv/libxml_nif.so: src/libxml_nif.c priv/libxml2/lib/libxml2.a
	cc -fPIC -I$(ERL_INCLUDE_PATH) -Ipriv/libxml2/include/libxml2 -Lpriv/libxml2/lib -shared $(DARWIN_LDFLAGS) -o $@ src/libxml_nif.c priv/libxml2/lib/libxml2.a

priv/libxml2/lib/libxml2.a:
	@rm -rf libxml2_build
	mkdir -p libxml2_build
	cd libxml2_build \
		&& $(CURL) http://xmlsoft.org/sources/libxml2-2.9.4.tar.gz \
		&& echo "$(LIBXML2_SHA256) *libxml2-2.9.4.tar.gz" | $(SHASUM) -c \
		&& tar xf libxml2-2.9.4.tar.gz \
		&& cd libxml2-2.9.4 \
		&& ./configure --prefix=`pwd`/../../priv/libxml2 --with-pic --without-python \
		&& make -j2 \
		&& make install
	@rm -rf libxml2_build

clean:
	@rm -rf libxml2_build
	@rm -rf priv/libxml2
	@rm -rf priv/libxml_nif.so
	@rm -rf _build
