Level = require('./Level')
Session = require('./sessions/LevelSession')
SessionHandler = require('./sessions/level_session_handler')
Feedback = require('./feedbacks/LevelFeedback')
Handler = require('../commons/Handler')
mongoose = require('mongoose')

LevelHandler = class LevelHandler extends Handler
  modelClass: Level
  editableProperties: [
    'description'
    'documentation'
    'background'
    'nextLevel'
    'scripts'
    'thangs'
    'systems'
    'victory'
    'name'
    'i18n'
    'icon'
  ]

  getByRelationship: (req, res, args...) ->
    return @getSession(req, res, args[0]) if args[1] is 'session'
    return @getLeaderboard(req, res, args[0]) if args[1] is 'leaderboard'
    return @getAllSessions(req, res, args[0]) if args[1] is 'all_sessions'
    return @getFeedback(req, res, args[0]) if args[1] is 'feedback'
    return @sendNotFoundError(res)

  getSession: (req, res, id) ->
    @getDocumentForIdOrSlug id, (err, level) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res) unless level?
      return @sendUnauthorizedError(res) unless @hasAccessToDocument(req, level)

      sessionQuery = {
        level: {original: level.original.toString(), majorVersion: level.version.major}
        creator: req.user.id
      }

      # TODO: generalize this for levels that need teams
      team = req.query.team
      team ?= 'humans' if level.name is 'Project DotA'
      sessionQuery.team = team if team
      
      Session.findOne(sessionQuery).exec (err, doc) =>
        return @sendDatabaseError(res, err) if err
        if doc
          @sendSuccess(res, doc)
          return

        initVals = sessionQuery
        initVals.state = {complete:false, scripts:{currentScript:null}} # will not save empty objects
        initVals.permissions = [{target:req.user.id, access:'owner'}, {target:'public', access:'write'}]
        initVals.team = team if team
        session = new Session(initVals)
        session.save (err) =>
          return @sendDatabaseError(res, err) if err
          @sendSuccess(res, @formatEntity(req, session))
          # TODO: tying things like @formatEntity and saveChangesToDocument don't make sense
          # associated with the handler, because the handler might return a different type
          # of model, like in this case. Refactor to move that logic to the model instead.

  getAllSessions: (req, res, id) ->
    @getDocumentForIdOrSlug id, (err, level) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res) unless level?
      return @sendUnauthorizedError(res) unless @hasAccessToDocument(req, level)

      sessionQuery = {
        level: {original: level.original.toString(), majorVersion: level.version.major}
        #creator: req.user.id
        submitted: true
      }
      Session.find sessionQuery, '_id totalScore submitted team creatorName', (err, results) =>
        return @sendDatabaseError(res, err) if err
        res.send(results)
        res.end()
        
  getLeaderboard: (req, res, id) ->
    # stub handler
#    [original, version] = id.split('.')
#    version = parseInt version
#    console.log 'get leaderboard for', original, version, req.query
    @getDocumentForIdOrSlug id, (err, level) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res) unless level?
      return @sendUnauthorizedError(res) unless @hasAccessToDocument(req, level)

      if parseInt(req.query.order) is 1
        scoreQuery = {"$gte":parseFloat req.query.scoreOffset}
      else
        scoreQuery = {"$lte": parseFloat req.query.scoreOffset}

      sessionsQuery =
        level: {original: level.original.toString(), majorVersion: level.version.major}
        team: req.query.team
        totalScore: scoreQuery
        submitted: true
      console.log sessionsQuery
      query = Session.find(sessionsQuery).sort({"totalScore":parseInt(req.query.order)}).limit(parseInt req.query.limit)
      Session.find sessionsQuery, '_id totalScore submitted team creatorName', (err, resultSessions) =>
        return @sendDatabaseError(res, err) if err
        if resultSessions
          return @sendSuccess res, resultSessions
        res.send([])

  getFeedback: (req, res, id) ->
    @getDocumentForIdOrSlug id, (err, level) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res) unless level?
      return @sendUnauthorizedError(res) unless @hasAccessToDocument(req, level, 'get')

      feedbackQuery = {
        creator: mongoose.Types.ObjectId(req.user.id.toString())
        'level.original': level.original.toString()
        'level.majorVersion': level.version.major
      }

      Feedback.findOne(feedbackQuery).exec (err, doc) =>
        return @sendDatabaseError(res, err) if err
        return @sendNotFoundError(res) unless doc?
        @sendSuccess(res, doc)
        return

  postEditableProperties: ['name']

module.exports = new LevelHandler()
