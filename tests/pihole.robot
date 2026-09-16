*** Settings ***
Library    SSHLibrary

*** Variables ***
${CLUSTER_USER}     admin
${CLUSTER_PASSWORD}    Nethesis,1234
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

Check if pihole configuration reads back
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be Equal    ${config}[http2https]    ${FALSE}

Check if the web password stays out of the environment
    # 10configure_environment_vars writes it to password.env, which the unit
    # passes to the container: it must not land in state/environment
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/environment'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    ${TEST_PASSWORD}

Check if the DNS server answers
    # The pod publishes 53 on the node: resolving through it is what the module
    # exists for, and the web interface says nothing about it. dig is not
    # installed on a bare node, so the query is built by hand and the answer
    # count of the reply header is what gets asserted.
    ${output}  ${rc} =    Execute Command
    ...    python3 -c 'import socket,struct; q=b"\\x12\\x34\\x01\\x00\\x00\\x01"+b"\\x00"*6+b"\\x0anethserver\\x03org\\x00\\x00\\x01\\x00\\x01"; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(10); s.sendto(q,("127.0.0.1",53)); d=s.recvfrom(512)[0]; print(struct.unpack("!H",d[6:8])[0])'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Be Equal    ${output.strip()}    0

Check if the services are running
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active pihole.service pihole-app.service
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if a configuration without the password is refused
    # The agent exits 10 on a JSON Schema input validation failure
    ${errors}  ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","http2https":false,"lets_encrypt":false}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  10
    # A missing required field is reported on the whole object, and the field
    # name goes to stderr, which Execute Command does not return here
    Should Contain    ${errors}    (root)_required

Take screenshots of the module pages
    [Documentation]    Capture what cluster-admin shows, for the software center
    ...                entry. Tagged ui: the shared runner skips it unless
    ...                RUN_UI_TESTS is true, since it needs a browser.
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True    viewport={'width': 1280, 'height': 900}
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    # The page fills itself from several tasks: let them land
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=about
    Wait For Elements State    iframe >>> h2 >> text="About"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/3._About.png
    Close Browser

Check if pihole is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Pihole login page is served
    # /admin/login, not /admin/: that one is a 302 with an empty body, which
    # curl -f accepts without reaching the application.
    ${output}  ${rc} =    Execute Command
    ...    curl -fsS -H 'Host: ${TEST_HOST}' http://127.0.0.1/admin/login
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${PIHOLE_TITLE}
    Should Contain    ${output}    ${LOGIN_FORM}
