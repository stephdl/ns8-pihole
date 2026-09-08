*** Settings ***
Library    SSHLibrary

*** Variables ***
${TEST_HOST}        pihole.ns8-ci.test
${TEST_PASSWORD}    Nethesis,1234
# Only the prefix: the rest of the title is the container hostname, which
# podman takes from the pod name.
${PIHOLE_TITLE}     <title>Pi-hole${SPACE}
${LOGIN_FORM}       <form id="loginform">

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

Check if the pihole virtualhost serves the login page
    Wait Until Keyword Succeeds    120s    5s    Pihole login page is served

Check if pihole is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Keywords ***
Pihole login page is served
    # configure-module sets a Host-based traefik route with no path prefix, so
    # the vhost only answers with the right Host header. /admin/login rather
    # than /admin/, which is a 302 with an empty body: a status check alone
    # would pass on it and prove nothing about the application.
    ${output}  ${rc} =    Execute Command
    ...    curl -fsS -H 'Host: ${TEST_HOST}' http://127.0.0.1/admin/login
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    # The title proves pihole answered rather than another vhost, the form
    # proves the interface actually rendered.
    Should Contain    ${output}    ${PIHOLE_TITLE}
    Should Contain    ${output}    ${LOGIN_FORM}
