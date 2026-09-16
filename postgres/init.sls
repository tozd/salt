{% set shim_dir = '/usr/local/lib/salt-psql-shim' %}
{% set configured_dir = salt['config.option']('postgres.bins_dir') %}
{% set configured_user = salt['config.option']('postgres.user') %}
{% set psql_on_path = salt['cmd.which']('psql') %}

# Lets Salt's postgres states reach a PostgreSQL running in a container.
#
# Salt's postgres states are written against a psql which connects to the PostgreSQL, so what is installed here is a psql shim which instead hands the work to
# psql inside the container which connects over the socket and authenticates with peer or trust auth. Nothing else about them changes, and no port has to be
# published for it.

# The directory is deliberately not on PATH. Salt looks for psql on PATH first and only falls back to postgres.bins_dir when it finds none, so this stands in
# exactly as long as no real client is installed beside it.
{{ shim_dir }}:
  file.directory:
    - user: root
    - group: root
    - mode: 755

{{ shim_dir }}/psql:
  file.managed:
    - source: salt://postgres/psql.sh
    - user: root
    - group: root
    - mode: 755
    - reload_modules: true
    - require:
      - file: {{ shim_dir }}

{% if psql_on_path %}
# A real client takes precedence over the one installed here, and then the postgres states talk to this machine, where there is no database, rather than to a
# container. They fail while looking like they were pointed at the wrong database.
postgres-client-must-not-be-installed:
  test.fail_without_changes:
    - name: psql is installed at {{ psql_on_path }}, which takes precedence over {{ shim_dir }}/psql
    - comment: >
        Salt's postgres modules use the first psql on PATH and only fall back to postgres.bins_dir when there is none, so the shim this state installs is
        ignored for as long as {{ psql_on_path }} exists. Remove the postgresql-client package, or stop including the postgres state on this machine.
{% endif %}

{% if configured_dir != shim_dir %}
# Without this the shim is installed and never used, which is the same as not installing it, except that it looks as though something is in place.
postgres-bins-dir-must-be-configured:
  test.fail_without_changes:
    - name: postgres.bins_dir is {{ configured_dir | default('unset', true) }}, not {{ shim_dir }}
    - comment: >
        Add "postgres.bins_dir: {{ shim_dir }}" under ssh_minion_opts in config/master.
{% endif %}

{% if not configured_user %}
# The shim names no user to "docker exec", so psql runs as whoever the image runs as and asks for the role of that name. A container running as root then asks
# for a role "root", and postgres.db_list answers that with an empty list rather than an error, which a state reads as "the database is not there".
postgres-user-must-be-configured:
  test.fail_without_changes:
    - name: postgres.user is unset
    - comment: >
        Add "postgres.user: <role>" under ssh_minion_opts in config/master, naming the role the containers are reached as. It is the role which owns the
        cluster, "postgres" unless the image was built otherwise.
{% endif %}
