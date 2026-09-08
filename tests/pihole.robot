*** Settings ***
Library    SSHLibrary

*** Variables ***
${TEST_HOST}        pihole.ns8-ci.test
${TEST_PASSWORD}    Nethesis,1234

*** Test Cases ***
Check if pihole is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if pihole can be configured
    # The schema declares every property as required, so a partial payload is
    # rejected. http2https stays false to keep the next test case on plain HTTP.
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","http2https":false,"lets_encrypt":false,"webpassword":"${TEST_PASSWORD}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the pihole virtualhost answers
    Wait Until Keyword Succeeds    120s    5s    Pihole vhost is reachable

Check if pihole is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Keywords ***
Pihole vhost is reachable
    # configure-module sets a Host-based traefik route with no path prefix, so
    # the vhost is only reachable with the right Host header. /admin/ rather
    # than /, which answers 302 before the application is up.
    ${rc} =    Execute Command
    ...    curl -fsS -H 'Host: ${TEST_HOST}' http://127.0.0.1/admin/
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
