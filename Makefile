.DELETE_ON_ERROR:
.PHONY: FORCE
.SUFFIXES:

ORG:=ga4gh


default:
	@echo No $@ target 1>&2; exit 1


.PHONY: update-list
update-list:
	rm -f ${ORG}/descriptions ${ORG}/avail; make ${ORG}/avail

# ${ORG}/descriptions: list of available repos w/descriptions
.PRECIOUS: ${ORG}/descriptions
${ORG}/descriptions:
	gh repo list ga4gh -L 1000 | sort -u >$@ 

# ${ORG}/avail: list of available repos
.PRECIOUS: ${ORG}/avail
${ORG}/avail: ${ORG}/descriptions
	cut -f1 <$< | sort -u >$@

# ${ORG}/known: repos that we've seen before
.PRECIOUS: ${ORG}/known
${ORG}/known: ${ORG}/ignore ${ORG}/snarf
	sort -u $^ >$@

# ${ORG}/new: new repos that need classifying
.PRECIOUS: ${ORG}/new
${ORG}/new: ${ORG}/avail ${ORG}/known
	comm -23 $^ | sort -u >$@
	@if [ -s "$@" ]; then echo "$$(wc -l $@) new repos in $@ need classifying; move to ignore or snarf before proceeding" 1>&2; exit 1; fi

# ${ORG}/snarf: repos to actually snarf
.PRECIOUS: ${ORG}/snarf
${ORG}/snarf: ${ORG}/avail ${ORG}/ignore
	comm -23 $^ | sort -u >$@
	
.PHONY: rebuild
rebuild:
	/bin/ls -1d ${ORG}/* | sort -u >|${ORG}/snarf
	make update-list
	make ${ORG}/snarf

# snarf
.PHONY: snarf
snarf: ${ORG}/snarf
	@while read repo; do \
		if [ -d "$$repo" ]; then \
			(set -x; git -C "$$repo" pull); \
		else \
			(set -x; gh repo clone "$$repo" "$$repo"); \
		fi; \
	done <$<

stats: ${ORG}/snarf
	perl -la -ne 'print("stats/$$_.stats")' <$< | xargs make

results/github-stats-summary.tsv: stats FORCE
	(cd $<; perl -lne 'if (m/^ts/) { print "repo\t$$_" if $$.==1 } else {($$repo = $$ARGV) =~ s%\.stats$$%%; print("$$repo\t$$_")}'  ${ORG}/*.stats) >$@

.PRECIOUS: stats/%.log
stats/%.log: %
	@mkdir -p ${@D}
	git -C $< log --no-merges --format=format:"%aI %h %aE %cE %s" --shortstat >$@

stats/%.stats: stats/%.log
	${HOME}/opt/reece-base/bin/git-commit-stats <$< >$@
