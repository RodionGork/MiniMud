var input = document.getElementById('command');

input.onkeydown = function() {
    if (event.key != 'Enter') return;
    var cmd = input.value.trim();
    if (cmd == '') return;
    addDiv('useract', cmd);
    sendCmd(cmd);
    input.value = '';
}

function addDiv(cls, text) {
    var div = document.createElement('div');
    div.classList.add(cls);
    div.innerHTML = text;
    document.body.insertBefore(div, input.parentElement);
    document.body.scrollTo(0, document.body.scrollHeight - document.body.clientHeight);
}

var commError = false;
var chkevtToBase = 4000;
var chkevtToVar = 3000;

function sendCmd(cmd) {
    nextEventCheck = new Date().getTime() + chkevtToBase + Math.round(Math.random() * chkevtToVar);
    var m = location.href.match(/\?token\=([0-9a-zA-Z_\-]+)/);
    if (m === null) {
        respond('You need a magical token to communnicate to server!');
        return;
    }
    var token = m[1];
    var url = urlFromToken(m[1]);
    fetch(url, {
        method: 'POST', body: m[1] + '\n' + cmd
    }).then((resp) => {
        if (resp.status != 200) {
            if (!commError)
                respond('Sorry, exchange error: ' + resp.status);
            commError = true;
        } else {
            commError = false;
            resp.text().then((data) => respond(data));
        }
    }).catch((err) => {
        if (!commError)
            respond('Ah, oh, error: ' + err)
        commError = true;
    });
}

function respond(text) {
    text = text.replace(/%:(.)/g, (m, c) => `<span class="x-${c[0]}">`).replace(/:%/g, `</span>`).replace(/\n/g, '<br/>');
    if (text.trim() !== '')
        addDiv('machine', text);
}

function urlFromToken(token) {
    return atob(token.substr(27)).split(' ')[1];
}

var nextEventCheck = 0;

function eventsCheck() {
    var cur = new Date().getTime();
    if (nextEventCheck > cur)
        return;
    sendCmd('chkevt');
}

setInterval(eventsCheck, 1000 + Math.floor(Math.random()*100));

