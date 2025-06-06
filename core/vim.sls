vim:
  pkg.latest:
    - refresh: true
    - cache_valid_time: 600

vim-editor:
  alternatives.set:
    - name: editor
    - path: /usr/bin/vim.basic
    - require:
      - pkg: vim
