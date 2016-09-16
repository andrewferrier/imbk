build: clean define-env-vars
	fastlane beta

clean:
	-fastlane clean

lint:
	swiftlint

define-env-vars:
	. fastlane/local_fastlane_testing.sh

run-test-ssh-server:
	mkdir -pv /tmp/imbk_testing
	docker run -v /tmp/imbk_testing:/data/incoming -p 5222:22 -e USER=imbk -e PASS=imbk writl/sftp
