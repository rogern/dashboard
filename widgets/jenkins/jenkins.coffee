class Dashing.Jenkins extends Dashing.Widget

  sounds = ['Building', 'Failure', 'Success']

  ready: ->

  onData: (data) ->
    action = (item for item in data.items when item.status in sounds).sort (a,b) -> return if a.status >= b.status then 1 else -1

    console.log("got data")

    if action[0]
      audio = new Audio('/assets/' + action[0].status + '.wav')
      audio.play()
