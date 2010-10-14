
PKG = $(shell basename `pwd`)
FILES = README $(PKG).ins $(PKG).dtx
RESULTS = $(PKG).pdf $(PKG).sty

CTAN = $(PKG).tar.gz
TDS = $(PKG).tds.zip

$(TDS): $(CTAN)
	tar xzf $(CTAN)
	rm -rf $(PKG)/

$(CTAN): $(FILES) $(RESULTS)
	ctanify $(PKG).ins $(PKG).pdf README

$(PKG).ins: $(PKG).dtx
	tex $<

$(PKG).pdf: $(PKG).dtx
	pdflatex $<
	pdflatex $<
	pdflatex $<

$(PKG).sty: $(PKG).ins
	tex $<

README: README.markdown
	cp -f $< $@

.PHONY: clean

clean:
	rm -f $(RESULTS) $(PKG).ins README $(PKG).aux $(PKG).log $(PKG).pdf $(PKG).idx $(PKG).tar.gz $(PKG).hd $(PKG).out $(PKG).toc $(PKG).txt




###### NIGHTLY BUILDS ######

# Mac OS X specific:
GETPASSWORD := $(shell security 2>&1 >/dev/null find-internet-password -gs tlcontrib.metatex.org | cut -f 2 -d ' ')
GETUSERNAME = := $(shell security find-internet-password -s tlcontrib.metatex.org | grep "acct" | cut -f 4 -d \")

BRANCH = tdsbuild

TMP = /tmp
MD5 = md5
LOG =  $(TMP)/gitlog.tmp
PASSWORD = $(GETPASSWORD)
USERNAME = $(GETUSERNAME)
VERSION := $(shell date "+%Y-%m-%d@%H:%M")
CHECKSUM := $(shell echo $(USERNAME)/$(PASSWORD)/$(VERSION) | $(MD5) )
TLC := http://tlcontrib.metatex.org/cgi-bin/package.cgi/action=notify/key=$(PKG)/check=$(CHECKSUM)?version=$(VERSION)


hello:
	@echo $(USERNAME)
	@echo $(PASSWORD)
	@echo $(VERSION)
	@echo $(CHECKSUM)
	@echo $(TLC)

checkbranch:
	@if  git branch | grep $(BRANCH) > /dev/null ; \
	then echo "TDS branch exists"; \
	else \
	  echo "TDS branch does not exist; doing so will remove all untracked files from your working directory. Create the TDS branch with\n    make createbranch"; \
	  false;
	fi;

createbranch: $(TDS)
	cp -f $(TDS) $(TMP)/
	git symbolic-ref HEAD refs/heads/$(BRANCH)
	rm .git/index
	git clean -fdx
	unzip -o $(TMP)/$(TDS) -d .
	rm $(TMP)/$(TDS)
	git add --all
	git commit -m "Initial TDS commit"
	git checkout master
	git push origin $(BRANCH) master
	@echo "Pinging TLContrib for automatic update"
	curl $(TLC) > /dev/null 2>&1


tdsbuild: checkbranch $(TDS)
	cp -f $(TDS) $(TMP)/
	@echo "Constructing commit history for snapshot build"
	date "+TDS snapshot %Y-%m-%d %H:%M" > $(LOG)
	echo '\n\nApproximate commit history since last snapshot:\n' >> $(LOG)
	git log --after="`git log -b tds-build -n 1 --pretty=format:"%aD"`" --pretty=format:"%+H%+s%+b" >> $(LOG)
	@echo "Committing TDS snapshot to separate branch"
	git checkout tds-build
	unzip -o $(TMP)/$(TDS) -d .
	rm $(TMP)/$(TDS)
	git commit --all --file=$(LOG)
	git clean -df
	@echo "Pushing TDS and master branch"
	git checkout master
	git push origin $(BRANCH) master
	@echo "Pinging TLContrib for automatic update"
	curl $(TLC) > /dev/null 2>&1


