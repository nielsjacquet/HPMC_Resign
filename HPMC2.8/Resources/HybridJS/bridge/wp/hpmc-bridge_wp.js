function NativeCommunication() {

    /** privates declaration */
    
    var urlFormat = "hpmcwebviewevent/?action=";
    var MAX_URI_LENGTH = 2083;
    var MAX_MESSAGE_LENGTH = MAX_URI_LENGTH - 600; // experimentaly, this value works 0___0, increase if messages get "lost"
        
    function getDpr() { // http://stackoverflow.com/questions/16383503/window-devicepixelratio-does-not-work-in-ie-10-mobile
        if (screen.msOrientation == "portrait-primary") {
            return Math.round(screen.availWidth * window.devicePixelRatio / 4) * 4 / document.body.clientWidth;
        }
        return Math.round(screen.availHeight * window.devicePixelRatio / 4) * 4 / document.body.clientHeight;
    }
    
    function sendMessageToNativeUsingIFrame(action, params) {
        var url = urlFormat + action;
        if (params) {
            for(var paramName in params) {
                if (params.hasOwnProperty(paramName)) {
                    var paramVal = params[paramName];
                    url += "&" + paramName + "=" + paramVal;
                }
            }
        }
        
        getLogger().log("url is: " + url);
        getLogger().log("url length is : " + url.length);
        var iframe = document.createElement("IFRAME");
        iframe.setAttribute("src", url);
        iframe.setAttribute("visibility", "hidden");
        iframe.style.display = "none";
        document.documentElement.appendChild(iframe);
        iframe.parentNode.removeChild(iframe);
        iframe = null;
    }
          
    function hasBridge() {
        return window.recordReplayBridge;
    }
                	                 
	function getLogger() { // TODO maybe it will be better to define external log
        return console;
    };
    
    /** ends of privates declaration */

    
    this.getZoomFactor = function (toDomValues) {
        var windowWidth = window.innerWidth; // the returned zoom factor will be 1 if an error occures
        
        if (document.compatMode=='CSS1Compat' && document.documentElement && document.documentElement.offsetWidth) {
            windowWidth = document.documentElement.offsetWidth;
        }
        else if (document.body && document.body.offsetWidth) {
            windowWidth = document.body.offsetWidth;
        }
        
        return toDomValues ? window.innerWidth / windowWidth : windowWidth / window.innerWidth;
    };

    // In wp the window.outerWidth returns the correct WebView width
    // so no need for the value returned from the native
    this.setOuterWidth = function() {
    };

    /** in wp the device works in pixels, so value conversion by dpr is needed */
    this.convertLogicalToDeviceValue = function(logicalVal) {        
        return logicalVal * getDpr();
    };

    /** in wp the device works in pixels, so value conversion by dpr is needed */
    this.convertDeviceToLogicalValue = function(deviceVal) {       
        return deviceVal / getDpr();
    };    
        
    this.sendMessage = function(type, message, nativeContext) {
        getLogger().log("pass to bridge type " + type + " message " + message + " context " + nativeContext);
        getLogger().log("Message length is: " + message.length);

        var segments = Math.ceil(message.length / MAX_MESSAGE_LENGTH);
        getLogger().log("fitting into segments: " + segments);
        for (var i = 0; i < segments; i++) {
            getLogger().log("Sending segment: " + i);
            var segmentedMessage = message.substring(i * MAX_MESSAGE_LENGTH, (i + 1) * MAX_MESSAGE_LENGTH);
            sendMessageToNativeUsingIFrame("sendMessage", { type: type, message: segmentedMessage, context: nativeContext, segment: i + 1, totalSegments: segments });
        };
    };

    this.sendQueryResultFromHpmcBridge = function(queryResult, nativeContext) {
        getLogger().log("about to send query result: " + JSON.stringify(queryResult));
        sendMessageToNativeUsingIFrame('findElementResponse', {message: JSON.stringify(queryResult), context: nativeContext});
    };

    this.getState = function(){
        sendMessageToNativeUsingIFrame("getState");
    };

    this.setState = function(state){
        sendMessageToNativeUsingIFrame("setState", {state: state});
    };

    this.getWebViewBounds = function () {
        // Instead of sendMessageToNativeUsingIFrame("getWebViewBounds") we add the webview bounds to the window object and send response back directlly to the bridge
		if(window._hpmcBridge && window._webViewBounds){			
				window._hpmcBridge.getWebViewBoundsResponse(window._webViewBounds, "");
		}
    };  
}

window.hpmcAgent = "wp";window._hpmcBridge = window._hpmcBridge || new function HpmcBridge() {

    this.ScreenRatioType = {
        X: "appToScreenRatioX",
        Y: "appToScreenRatioY"
    };

    var stateCallbacks = [];
    var communication = new NativeCommunication();
    var screenRatios = {};

    /**
    * bellow method should be override by the js client in order to register for rnr events.
    */

    /**
     * onStartRecord() called to indicate that record is starting.
     * @param {Function} eventcallback – a callback which should be called to indicate success or failure
     * @returns {undefined}
     */
    this.onStartRecord = null;

    /**
     * onStopRecord() called to indicate that record is ending.
     * @param {Function} eventcallback – a callback which should be called to indicate success or failure
     * @returns {undefined}
     */
    this.onStopRecord = null;

    /**
     * onStartReplay() called to indicate that replay is starting.
     * @param {Function} eventcallback – a callback which should be called to indicate success or failure
     * @returns {undefined}
     */
    this.onStartReplay = null;

    /**
     * onStopReplay() called to indicate that record is ending.
     * @param {Function} eventcallback – a callback which should be called to indicate success or failure
     * @returns {undefined}
     */
    this.onStopReplay = null;

    /**
     * onRequest() called when a new request is received. A request is a message that requires a response.
     * @param {Object} message – the request message sent by the testing tool.
     * @param {Function} responseCallback – callback function to be used to send the response for this specific request.
     * @returns {undefined}
     */
    this.onRequest = null;

    /**
     * onWaitForWebObject() called on native-to-web 'waitFor' action.
     * @param {Object} message – the request message sent by the testing tool ("webData").
     * @param {Integer} timeout – the remaining time to wait for the web element to be found (milliseconds).
     * @param {Function} responseCallback – callback function to be used to send the response.
     * @returns {undefined}
     */
    this.onWaitForWebObject = null;
    /**
     * onFindElement() called to when a findElement command is executed on the bridge.
     * param {JsonObject} query by which to locate the elements.
     * @param {Function} queryCallback – a callback which is called with the find results payload or error if occurred.
     * @returns {undefined}
     */
    this.onFindElement = null;

    /**
     * onWebViewVisible(isVisible) called when the webView change visibility.
     * @param {Boolean} isVisible - true - visible, false - invisible
     * @returns {JsonObject} - json object to pass to Tool's main.
     */
    this.onWebViewVisible = null;

    /**
     * setState(state) set or override runtime state of the Webview.
     * @param {JsonObject} state.
     * @param {Function} external JS callback.
     * @returns {undefined}
     */
    this.setState = function(state, callback){
        var stateStr = JSON.stringify(state);
        this.setStateResponse.callbackQueue.push(callback);
        communication.setState(stateStr);
    };

    /**
     * getState(state) get runtime state of the Webview.
     * @param {Function} external JS callback.
     * @returns {undefined}
     */
    this.getState = function(callback){
        this.getStateResponse.callbackQueue.push(callback);
        communication.getState();
    };

    /**
     * responseCallback() called to send a response for the appropriate request
     * @param {*} error – falsy if the sendMessage succeeded. truthy otherwise
     * @param {Object} responseMsg – the response message that should be forwarded to the testing tool which sent the request message which included this callback function
     * @returns {undefined}
     */
    function responseCallback(error, responseMsg) {
        console.log(this.context);
        if(error) {
            console.log("request failed");
        }
        var msgToSend = responseMsg;
        try {
            if(typeof responseMsg != "string") {
                msgToSend = JSON.stringify(responseMsg);
            }
            communication.sendMessage('JsResponse', msgToSend, this.context);
        } catch(e) {
            console.error("failed sending message " + msgToSend + " - exception: " + e);
        }
    }

    /**
     * waitForWebObjectCallback() called to send a response for the appropriate request
     * @param {Boolean} error – false if everything is fine
     * @param {Object} responseMsg – always returns JSON for webData (even on success)
     * @returns {undefined}
     */
    function waitForWebObjectCallback(error, responseMsg) {
        console.log(this.context);
        var response = {error: error, message: responseMsg};

        try {
            communication.sendMessage('JsResponse', JSON.stringify(response), this.context);
        } catch(e) {
            console.error("failed sending message " + response + " - exception: " + e);
        }
    }

    /**
     * responseCallback() called to send a findElement results
     * @param {*} error – falsy if the sendMessage succeeded. truthy otherwise
     * @param {Object} results – results returned that return to the native
     * @returns {undefined}
     */
    function queryCallback(error, results) {
        console.log(this.context);
        if(error) {
            console.log("request failed");
        }
        communication.sendQueryResultFromHpmcBridge(results, this.context);
    }

    // we save last state - in case we call to change state (e.g startRecord/startReplay) before tool connected.
    // then we'll call the state callback in connect()
    var _currentState = null;
    /**
     * connect() called to the indicate the js client finished registering to all the relevant events and ready to receive events.
     */
    this.connect = function(onConnect) {
        stateCallbacks['startRecord'] = this.onStartRecord;
        stateCallbacks['stopRecord'] = this.onStopRecord;
        stateCallbacks['startReplay'] = this.onStartReplay;
        stateCallbacks['stopReplay'] = this.onStopReplay;
        stateCallbacks['request'] = this.onRequest;
        stateCallbacks['webViewVisible'] = this.onWebViewVisible;
        console.log('set callback');

        // This didn't tested for Android - so for now it's only for iOS
        if (window.hpmcAgent == "ios" && _currentState) {
          setTimeout(function (){ doStateMsg(_currentState)}, 0);
        }
    };

    /**
     * sendEvent() called to notify the testing tool of an event
     * @param {Object} eventMsg – the event message sent by the testing tool
     * @param {Function} eventcallback – a callback which should be called by the mobile framework to indicate success or failure in delivering the event. eventCallback was defined previously under the record/replay section.
     * @returns {undefined}
     */
    this.sendEvent = function(eventMsg, eventCallback) {
        try {
            var eventToSend = stringify(eventMsg);

            communication.sendMessage('JsEvent', eventToSend, null);
        } catch(e) {
            console.error("failed sending message " + eventToSend + " - exception: " + e);
            eventCallback(e);
            return;
        }

        eventCallback();
    };

    function stringify (eventMsg) {

        if(typeof eventMsg != "string") {
            eventMsg = JSON.stringify(eventMsg);
        }

        return eventMsg;
    };

    /**
     * sendWebRequest() is called to send web request to the testing tool.
     * @param isSync
     * @param eventMsg
     * @param eventCallback
     * @param timeout
    */
    this.sendWebRequest = function(isSync, eventMsg, eventCallback, timeout) {
        try {
            // MC currently only supports sync web request without callback
            // The sync web response result will be stored in the localStorage "hpmc_js_sync_response"
            isSync = true;
            eventCallback = null;
            var eventToSend = stringify(eventMsg);
            communication.sendWebRequest(isSync, eventToSend, eventCallback, timeout);
        } catch(e) {
            console.error("failed to send sync web request " + eventToSend + " - exception: " + e);
            if (eventCallback) {
                eventCallback(e);
            }
            return;
        }
    };

    this.onMessage = function(command, message, nativeContext) {
        if(command != undefined) {
            switch(command) {
                case "startRecord":
                case "startReplay":
                case "stopRecord" :
                case "stopReplay" :
                    doStateMsg(command);
                    break;
                case "request" :
                    setTimeout(doRequestMessage.bind(this, message, nativeContext), 0);
                    break;
                case "webViewVisible":
                    if (stateCallbacks[command]) {
                        // in visibility api - 'message' will be boolean, not string: true/false, indicates webView visible/invisible
                        return JSON.stringify(stateCallbacks[command](message));
                    } else {
                        return "";
                    }
                    break;
            }
        }
    };

    this.version = "2.80.00" + "-" + "10";

    /**
     * getWebViewBounds() get the bounds of the webview.
     * @param {Function} external JS callback.
     * @returns {undefined}
     */
    this.getWebViewBounds = function(callback) {
        this.getWebViewBoundsResponse.callbackQueue.push(callback);
        communication.getWebViewBounds();
    };

    this.setStateResponse = function (error){
        var callback = this.setStateResponse.callbackQueue.shift();
        if (callback) {
          callback(error);
        }
    };
    this.setStateResponse.callbackQueue = [];

    this.getStateResponse = function (state, error){
        var callback = this.getStateResponse.callbackQueue.shift();
        if (callback) {
          callback(error, state);
        }
    };
    this.getStateResponse.callbackQueue = [];

    this.getWebViewBoundsResponse = function (bounds, error) {
        var callback = this.getWebViewBoundsResponse.callbackQueue.shift();
        if (callback){
          callback(error, bounds);
        }
    };
    this.getWebViewBoundsResponse.callbackQueue = [];

    this.findElement = function(query, nativeContext) {
        var callBack = queryCallback.bind({ context: nativeContext });
        this.onFindElement(query, callBack);
    };

    this.waitForWebObject = function(message, timeout, nativeContext) {
        var callBack = waitForWebObjectCallback.bind({ context: nativeContext });
        if (this.onWaitForWebObject) {
          console.log("sending message to 'onWaitForWebObject' callback");
          this.onWaitForWebObject(message, timeout, callBack);
        } else {
          console.error("No callback for 'onWaitForWebObject' !");
        }
    };

    this.notifyInjected = function () {
        if (!this.isRefreshing) {
            communication.notifyInjected(location.href);
        } else {
            communication.notifyInjected("");
        }
    };

    /**
     * Converts given logical point value to the device measurement value
     * @param logicalVal logical point value
     * @param screenRatioType screen ratio to use in the conversion, use _hpmcBridge.ScreenRatioType values
     * @returns {number} device measurement value
     */
    this.convertLogicalToDeviceValue = function(logicalVal, screenRatioType) {
        var zoomFactor = communication.getZoomFactor(false),
            screenRatio = screenRatios[screenRatioType] || 1;

        console.log("convertLogicalToDeviceValue - zoomFactor: " + zoomFactor + ", screenRatio: " + screenRatio);

        return Math.round(communication.convertLogicalToDeviceValue(logicalVal) * zoomFactor * screenRatio);
    };

    /**
     * Converts given device measurement value to logical point value
     * @param deviceVal device measurement value
     * @returns {number} logical point value
     */
    this.convertDeviceToLogicalValue = function(deviceVal) {
        var zoomFactor = communication.getZoomFactor(true);

        console.log("convertDeviceToLogicalValue - zoomFactor: " + zoomFactor);

        return Math.round(communication.convertDeviceToLogicalValue(deviceVal) * zoomFactor);
    };

    this.getZoomFactor = function(toDomValues) {
        return communication.getZoomFactor(toDomValues);
    };

    this.setWebViewBounds = function(bounds) {
        communication.setOuterWidth(bounds);
    };

    this.appSpaceToScreenSpaceRatio = function(appToScreenRatioX, appToScreenRatioY) {
        console.log("appSpaceToScreenSpaceRatio set - " + this.ScreenRatioType.X + ": " + appToScreenRatioX +
            ", " + this.ScreenRatioType.Y + ": " + appToScreenRatioY);

        screenRatios[this.ScreenRatioType.X] = appToScreenRatioX;
        screenRatios[this.ScreenRatioType.Y] = appToScreenRatioY;

        return true;
    };

    function doStateMsg(command) {
        if(stateCallbacks.hasOwnProperty(command)) {
            console.log("executing command " + command + " " + stateCallbacks[command]);
            stateCallbacks[command](onEventCallBack);
        }
        // save command - in case connect() hadn't been called yet
        _currentState = command;
    }

    function doRequestMessage(message, nativeContext) {
        if(stateCallbacks["request"]) {
            var callBack = responseCallback.bind({ context: nativeContext });
            stateCallbacks["request"](message, callBack);
        } else {
            console.log("js client did not register for request message");
        }
    }

    function onEventCallBack(error) {
        if(error) {
            console.log("onEventCallBack error");
        } else {
            console.log("onEventCallBack success");
        }
    }

    function onComplete(error) {
        if(error) {
            console.log("on Complete error");
        } else {
            console.log("on complete success");
        }
    }

}();
/* Target approach: on top level window listen to dom content loaded (unless readyState is already interactive\complete, in which case run immediately)
* On frames, listen for window.onload, since they mistakenly report they are ready before they really are
* On both, listen to dom node inserted or mutation observer to detect new iframe creation
* On every iframe detected using the above methods, eval the scriptToInject (which in runtime should contain the JS engine)
*/

function hpmc_injectFrames() {
    var scriptToInject = "REPLACE_ME_WITH_SCRIPT";

    window.HPMC_IFRAME_ALREADY_INJECTED = true;

    var postDomLoadedStates = ['complete', 'interactive'];
    if (postDomLoadedStates.indexOf(document.readyState) !== -1) {
        // The DOM is already loaded, run immediately
        doBfsOnFrames(window, inject);
        attachDomListener(window);
    }
    else {
        // Wait for DOM load
        document.addEventListener("DOMContentLoaded", function(evt) {
            console.log("DOM content loaded");
            doBfsOnFrames(window, inject);
            attachDomListener(window);
        });
    }

    window.addEventListener("load",function() {
        doBfsOnFrames(window, injectAndAttachListener);
    });

    function injectAndAttachListener(frame) {
        inject(frame);
        attachDomListener(frame);
    }

    function inject(wnd) {
        try {
            if (wnd.HPMC_IFRAME_ALREADY_INJECTED) {
                return;
            }

            wnd.addEventListener("unload", function() {
                setTimeout(function() {
                    console.log("iframe navigation detected: %s", wnd.location.href);
                    inject(wnd);
                }, 0);
            }, false);

            if (wnd.location.href === "about:blank") {
                return;
            }

            wnd.HPMC_IFRAME_ALREADY_INJECTED = true;
            console.log("injecting frame: %s", wnd.location.href);
            wnd.eval("(" + scriptToInject + ")()");
        }
        catch (err) {
            console.log("Error while attempting to inject frame");
            console.log(err);
        }
    }

    function bfs(queue, selector, action) {
        var node = queue.shift();
        if (node) {
            action(node);
            var children = selector(node);
            bfs(queue.concat(children), selector, action);
        }
    }

    function doBfsOnFrames(wnd, action) {
        function selector(frame) {
            var frameIndex = frame.index;
            var subframes = [];
            var frameContent = frame.frame;

            for (var i = 0; i < frameContent.frames.length; ++i) {
                var newIndex = frameIndex.slice();
                newIndex.push(i);
                subframes.push({
                    frame : frameContent.frames[i],
                    index : newIndex
                });
            }

            return subframes;
        }

        var mainframe = {
            frame: wnd,
            index: [0]
        };

        bfs([mainframe], selector, function(frame) {
            console.log("bfs on frame: %s", frame.index.toString());
            action(frame.frame);
        });
    }

    function attachDomListener(wnd) {

        try {
            if (wnd.HPMC_IFRAME_DOM_LISTENER_ATTACHED) {
                return;
            }
            wnd.HPMC_IFRAME_DOM_LISTENER_ATTACHED = true;

            function handleNewNode(newNode) {
                if  (newNode.tagName && newNode.tagName.toLowerCase() === 'iframe') {
                    console.log("new iframe detected!");
                    console.log(newNode);

                    var newframe = newNode.contentWindow;
                    doBfsOnFrames(newframe, inject);

                    newframe.addEventListener("load",function() {
                        doBfsOnFrames(newframe, injectAndAttachListener);
                    });
                } else if (newNode.hasChildNodes()) {
                    var children = newNode.childNodes;
                    for (var i = 0; i < children.length; ++i) {
                        handleNewNode(children[i]);
                    }
                }
            }

            // Check if mutation observer is supported in this version
            if (wnd.MutationObserver) {
                console.log("Using mutation observer");
                var observer = new wnd.MutationObserver(function(mutations) {
                    for (var i = 0; i < mutations.length; ++i) {
                        var mutation = mutations[i];
                        for (var j = 0; j < mutation.addedNodes.length; ++j) {
                            handleNewNode(mutation.addedNodes[j]);
                        }
                    }
                });

                var target = wnd.document.body;
                var observeConf = {
                    childList: true,
                    subtree: true
                };
                observer.observe(target, observeConf);
            }
            else {
                // Use deprecated event
                console.log("Using DOM node inserted event");
                wnd.document.addEventListener("DOMNodeInserted", function(evt) {
                    handleNewNode(evt.target);
                });
            }
        }
        catch (err) {
            console.log("Error while attempting to inject frame");
            console.log(err);
        }
    }
}