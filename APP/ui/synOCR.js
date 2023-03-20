Ext.namespace("SYNO.SDS.synOCR.Utils");

Ext.apply(SYNO.SDS.synOCR.Utils, function(){
    return{
        getMainHtml: function(){
            // Timestamp must be inserted here to prevent caching of iFrame
            return '<iframe src="webman/3rdparty/synOCR/index.cgi?_ts=' + new Date().getTime() + '" title="react-app" style="width: 100%; height: 100%; border: none; margin: 0"/>';
        },
    }
}());

Ext.define("SYNO.SDS.synOCR.Application", {
    extend: "SYNO.SDS.AppInstance",
    appWindowName: "SYNO.SDS.synOCR.MainWindow",
    constructor: function(){
        this.callParent(arguments);
    }
});
 
Ext.define("SYNO.SDS.synOCR.MainWindow", {
    extend: "SYNO.SDS.AppWindow",
    constructor : function(a){
        var MY = SYNO.SDS.synOCR;
        this.appInstance = a.appInstance;
        MY.MainWindow.superclass.constructor.call(this, Ext.apply({
            layout : "fit",
            resizable : true,
            cls: "syno-my-win",
            maximizable : true,
            minimizable : true,
            width : 1024,
            height : 768,
            html: MY.Utils.getMainHtml()
        }, a));
        MY.Utils.ApplicationWindow = this;
    },

    onOpen : function(){
        SYNO.SDS.synOCR.MainWindow.superclass.onOpen.apply(this, arguments);
    },

    onRequest : function(a){
        SYNO.SDS.synOCR.MainWindow.superclass.onRequest.call(this, a);
    },

    onClose : function(){
        clearTimeout(SYNO.SDS.synOCR.TimeOutID);
        SYNO.SDS.synOCR.TimeOutID = undefined;
        SYNO.SDS.synOCR.MainWindow.superclass.onClose.apply(this, arguments);
        this.doClose();
        return true;
    }
});