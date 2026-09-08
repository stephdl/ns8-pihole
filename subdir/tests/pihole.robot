*** Settings ***
Library    SSHLibrary

*** Variables ***
${TEST_HOST}        pihole.ns8-ci.test
${TEST_PASSWORD}    Nethesis,1234
# Prefix only: the title ends with the container hostname.
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
    # http2https false keeps the next case on plain HTTP.
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
    # /admin/login, not /admin/: that one is a 302 with an empty body, which
    # curl -f accepts without reaching the application.
    ${output}  ${rc} =    Execute Command
    ...    curl -fsS -H 'Host: ${TEST_HOST}' http://127.0.0.1/admin/login
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${PIHOLE_TITLE}
    Should Contain    ${output}    ${LOGIN_FORM}
