SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = source
BUILDDIR      = build
MEMORY_GEN_SCRIPT = memory_map_gen.py

# Catch-all target: route all unknown targets to Sphinx using the "make mode" option.
# $(O) is meant as a shortcut for $(SPHINXOPTS).
%:
	topwrap library update
	@python3 $(MEMORY_GEN_SCRIPT)
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
