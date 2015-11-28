vim:
  pkg.latest:
    - refresh: True

vim-editor:
  alternatives.set:
    - name: editor
    - path: /usr/bin/vim.basic
    - require:
      - pkg: vim
