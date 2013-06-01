class App.TaskWidget extends App.Controller
  events:
    'click    [data-type="close"]': 'remove'

  constructor: ->
    super
    @render()

    # rerender view
    App.Event.bind 'ui:rerender', (data) =>
      @render()

    # rebuild taskbar widget
    App.Event.bind 'auth', (user) =>
      App.TaskManager.reset()
      @el.html('')

  render: ->

    return if _.isEmpty( @Session.all() )

    tasks = App.TaskManager.all()
    item_list = []
    for task in tasks
      data =
        url:   '#'
        id:    false
        title: App.i18n.translateInline('Loading...')
        head:  App.i18n.translateInline('Loading...')
      worker = App.TaskManager.worker( task.key  )
      if worker
        meta = worker.meta()
        if meta
          data = meta
      data.title = App.i18n.escape( data.title )
      data.head  = App.i18n.escape( data.head )
      item = {}
      item.task = task
      item.data = data
      item_list.push item

    @html App.view('task_widget')(
      item_list:      item_list
      taskBarActions: @_getTaskActions()
    )

    dndOptions =
      tolerance:            'pointer'
      distance:             15
      opacity:              0.6
      forcePlaceholderSize: true
      items:                '> a'
      update:               =>
        items = @el.find('.taskbar > a')
        order = []
        for item in items
          key = $(item).data('key')
          if !key
            throw "No such key attributes found for task item"
          order.push key
        App.TaskManager.reorder( order  )

    @el.find( '.taskbar' ).sortable( dndOptions )

  remove: (e) =>
    e.preventDefault()
    key = $(e.target).parent().data('key')
    if !key
      throw "No such key attributes found for task item"

    # check if input has changed
    worker = App.TaskManager.worker( key )
    if worker && worker.changed
      if worker.changed()
        return if !window.confirm( App.i18n.translateInline('Tab has changed, you really want to close it?') )

    # check if active task is closed
    currentTask = App.TaskManager.get( key )
    tasks = App.TaskManager.all()
    active_is_closed = false
    for task in tasks
      if currentTask.active && task.key is key
        active_is_closed = true

    # remove task
    App.TaskManager.remove( key )
    @render()

    # navigate to next task if needed
    tasks = App.TaskManager.all()
    if active_is_closed && !_.isEmpty( tasks )
      task_last = undefined
      for task in tasks
        task_last = task
      if task_last
        worker = App.TaskManager.worker( task_last.key )
        if worker
          @navigate worker.url()
        return
    if _.isEmpty( tasks )
      @navigate '#'

  _getTaskActions: ->
    roles  = App.Session.get( 'roles' )
    navbar = _.values( @Config.get( 'TaskActions' ) )
    level1 = []

    for item in navbar
      if typeof item.callback is 'function'
        data = item.callback() || {}
        for key, value of data
          item[key] = value
      if !item.parent
        match = 0
        if !item.role
          match = 1
        if !roles && item.role
          match = _.include( item.role, 'Anybody' )
        if roles
          for role in roles
            if !match
              match = _.include( item.role, role.name )

        if match
          level1.push item
    level1

App.Config.set( 'task', App.TaskWidget, 'Widgets' )
