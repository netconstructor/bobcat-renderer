class Bobcat
    @log_error: (message) ->
        jQuery.post(Config.LOG_URL, {'message': message,})
    
    constructor: ->
        v = this
        @loaded = {}
        @waiting = {}
    
        @viewport = new Viewport(this)
        @renderer = new Renderer(@viewport)
        @navigator = new GPSNavigator(@viewport, @renderer, (status) ->
            Bobcat.change_switch_status('checkboxGPS', status)
        )
        
        @navigator.init()
        @router = new Router(@renderer, @navigator, (status) -> 
            Bobcat.change_switch_status('checkboxNav', status)
        )
        
        @locator = new Locator(@renderer, @router)
        
        $('#checkboxGPS').bind('enabled', =>
            @navigator.switch_on()
        )

        $('#checkboxGPS').bind('disabled', =>
            @navigator.switch_off()
        )
        
        $('#checkboxNav').bind('enabled', =>
            if not @router.enable()
                $('#checkboxNav').trigger("disable")
        )

        $('#checkboxNav').bind('disabled', =>
            @router.disable()
        )

        $('#map').live('pageshow', (event, ui) =>
            @renderer.resizeCanvas()
        )
    
        if Config.SQL_CACHE_ENABLED
            @cache = new SQLCache()
        else
            @cache = new MemoryCache()

        @viewport.go_to(Config.longitude(), Config.latitude(), 0)
        @viewport.check_data_coverage()
        @controller = new UIController(@renderer, @viewport, @locator, @router)
           
        new Searcher(@controller, @viewport)
        
        if Config.DEBUG
            $('body').append('<div id="fps"></div>')
            $('body').append('<div id="location"></div>')
        
        viewport = @viewport
        window.onunload = (e) ->
            viewport.update_coordinates()
            e.returnValue = true
            
    @status: (message) ->
        if message?
            $('.status').text(message).show()
        else    
            $('.status').hide('slow')
            
    @errorMessage: (message) ->
        Bobcat.status(message)
        $('.status').delay(5 * 1000).hide('slow')

    load_data: (index) ->
        @waiting[index] = true    
        
        key = "cache:#{ index[0] };#{ index[1] }"
        
        v = this

        @cache.get(index, (data)->
            v.data_loaded(index, data)
        , ->
            url = Config.API_FETCH_URL + index[0] + '/' + index[1]
            $.ajax({
                'url': url, 
                'dataType': 'json',
                'success': (data) ->
                    if data?
                        v.data_loaded(index, data)
                        v.cache.put(index, data)
                    else
                        Bobcat.log_error("Server return null instead of geodata")
                    return
                'error': (request, status, error) -> 
                    Bobcat.errorMessage("Unable to fetch data from server")
                    #TODO: Put fake geometry with "Your'e offline message"
                    return
            })
        )
        return
    
    data_loaded: (index, data) ->
        @loaded[index] = true
        delete @waiting[index]
        
        @renderer.load_data(index, data)
        
        invalidate = []
        for idx in @renderer.cached_indexes
            if not @viewport.is_index_visible(idx)
                invalidate.push(idx)
                delete @loaded[idx]
                delete @waiting[idx]
        
        for idx in invalidate
            @renderer.invalidate(idx)


        return
        
    is_loaded: (index) ->
        return @loaded[index] or @waiting[index]

    @onOffSwitch: (id) ->
        @change_switch_status(id, 'disabled')
        
        $('#' + id + '').change(->
            if $('#' + id + '').attr('checked')
                $('#' + id + '').trigger("enabled")
            else
                $('#' + id + '').trigger("disabled")
        )
        
        $('#' + id + '').bind('enable', -> 
            $('#' + id + '').attr('checked', true)
            $('label[for=' + id + ']').addClass('ui-btn-active')
            $('#' + id + '').trigger('change')
            return
        )    
        
        $('#' + id + '').bind('disable', -> 
            $('#' + id + '').attr('checked', false)
            $('label[for=' + id + ']').removeClass('ui-btn-active')
            $('#' + id + '').trigger('change')
            return
        )
        
    @change_switch_status: (id, status) ->
        if status == 'disabled'
            $('label[for=' + id + ']').removeClass('ui-btn-active')
            $('#' + id + '').attr('checked', false)
        else
            $('label[for=' + id + ']').addClass('ui-btn-active')
            $('#' + id + '').attr('checked', true)
        $('label[for=' + id + ']').removeClass('disabled').removeClass('enabled').removeClass('active')
        $('label[for=' + id + ']').addClass(status)
    

window.onerror = (msg, url, line) ->
    Bobcat.log_error("JS error: " + msg + " at " + url + ", line " + line)
    window.console && window.console.log("JS error: " + msg + " at " + url + ", line " + line)
    return false

$( "#search_results" ).bind( "listviewcreate", ->
    list = $( this )
    listview = list.data("listview")

    wrapper = $("<form>", { "class": "ui-listview-filter ui-bar-c", "role": "search", 'id': 'search_form'})
    
    search = $("<input>", {'placeholder': "Filter results...", "data-type": "search", 'id': 'query_string'}).appendTo( wrapper ).textinput()
    
    wrapper.addClass("ui-listview-filter-inset")
    wrapper.insertBefore(list)
    
    wrapper.submit(->
        $('#search_results').trigger('search', [$('#query_string').val()])
        return false
    )
)

$(document).bind('online', =>
    Bobcat.status()
)

$(document).bind('offline', =>
    Bobcat.status('Offline mode')
)

$(document).ready( ->
    $('#feedbackForm').bind('submit', (e) =>
        form = {
            'from': $('#from').val(),
            'message': $('#message').val()
        }
        
        $.mobile.pageLoading()
        $.ajax({
            type: 'POST',
            url: '/api/feedback', 
            dataType: 'json',
            data: form, 
            success: (data) ->
                $.mobile.pageLoading(true)
                $.mobile.changePage("#map");
            ,
            error: (jqXHR, textStatus, errorThrown) ->
                $.mobile.pageLoading(true)
                Bobcat.errorMessage("Cannot send feedback message. Please try email")
        })
        return false
    )

    Bobcat.onOffSwitch('checkboxGPS')
    Bobcat.onOffSwitch('checkboxNav')
    
    jQuery.fixedToolbars.setTouchToggleEnabled(false)
    new Bobcat()
)