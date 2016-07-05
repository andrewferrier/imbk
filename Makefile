build: clean define-env-vars
	fastlane beta

clean:
	-fastlane clean

define-env-vars:
	. fastlane/local_fastlane_testing.sh

run-test-ssh-server:
	docker run -v /tmp:/data/incoming -p 5222:22 -e USER=imbk -e PASS=imbk writl/sftp
