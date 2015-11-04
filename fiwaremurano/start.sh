sed -i -e "s/XXX/${PASSWORD}/" /opt/murano/etc/murano/murano.conf
git fetch https://review.openstack.org/openstack/murano refs/changes/$REVISION && git checkout FETCH_HEAD
cp -rf /opt/murano/meta2/* /opt/murano/meta
tox -e venv -- murano-db-manage \
  --config-file ./etc/murano/murano.conf upgrade
tox -e venv -- murano-api --config-file ./etc/murano/murano.conf &
while ! nc -z localhost 8082; do sleep 8; done
cd  ./meta/io.murano
zip -r ../../io.murano.zip *
cd ./../../
tox -e venv -- murano --murano-url http://localhost:8082 --os-username admin --os-password $PASSWORD \
  --os-tenant-name admin --os-auth-url=http://cloud.lab.fi-ware.org:4730/v2.0 \
  package-import --exists-action u  --is-public io.murano.zip
tox -e venv -- murano-engine --config-file ./etc/murano/murano.conf
