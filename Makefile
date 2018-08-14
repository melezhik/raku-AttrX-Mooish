
MAIN_MOD=lib/AttrX/Mooish.pm6
MOD_VER:=$(shell perl6 -Ilib -e 'use AttrX::Mooish; AttrX::Mooish.^ver.say')
MOD_NAME_PFX=AttrX-Mooish
MOD_DISTRO=$(MOD_NAME_PFX)-$(MOD_VER)
MOD_ARCH=$(MOD_DISTRO).tar.gz
META=META6.json
META_BUILDER=./build-tools/gen-META.p6

DIST_FILES=LICENSE \
			META6.json \
			Makefile \
			README.md \
			lib/AttrX/Mooish.pm6 \
			t/005-meta.t \
			t/010-base.t \
			t/020-role.t \
			t/030-inheritance.t 

CLEAN_FILES=$(MOD_NAME_PFX)-v*.tar.gz
CLEAN_DIRS=lib/.precomp

all: release

readme: README.md
	
README.md: $(MAIN_MOD)
	@echo "===> Generating $@"
	@perl6 --doc=Markdown $^ >$@

html: README.html

README.html: $(MAIN_MOD)
	@echo "===> Generating $@"
	@perl6 --doc=HTML $^ >$@

test:
	@prove -l --exec "perl6 -Ilib" -r t

author-test:
	@echo "===> Author testing"
	@AUTHOR_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

release-test:
	@echo "===> Release testing"
	@RELEASE_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

clean-repo:
	@git diff-index --quiet HEAD || (echo "*ERROR* Repository is not clean, commit your changes first!"; exit 1)

build: meta
	@echo "===> Installing dependencies"
	@zef --deps-only install .

release: build clean-repo release-test $(MOD_ARCH) 
	@echo "===> Done releasing"

meta: $(META)

$(MOD_ARCH): $(DIST_FILES)
	@echo "===> Creating release archive" $(MOD_ARCH)
	@echo "Generating release archive will tag the HEAD with current module version."
	@echo "Consider carefully if this is really what you want!"
	@/bin/sh -c 'read -p "Do you really want to tag? (y/N) " answer; [ $$answer = "Y" -o $$answer = "y" ]'
	@git tag -f $(MOD_VER) HEAD
	@git push -f --tags
	@git archive --prefix="$(MOD_DISTRO)/" -o $(MOD_ARCH) $(MOD_VER)

$(META): $(META_BUILDER) $(MAIN_MOD)
	@echo "===> Generating $(META)"
	@$(META_BUILDER) >$(META)

upload: release
	@echo "===> Uploading to CPAN"
	@/bin/sh -c 'read -p "Do you really want to upload to CPAN? (y/N) " answer; [ $$answer = "Y" -o $$answer = "y" ]'
	@cpan-upload -d Perl6 --md5 $(MOD_ARCH)
	@echo "===> Uploaded."

clean:
	@rm $(CLEAN_FILES)
	@rm -rf $(CLEAN_DIRS)

install: build
	@echo "===> Installing"
	@zef install .
