import {} from 'babel-register'

import { fetch } from './app/js/services.jsx'
import express from 'express'
import path from 'path'
import compression from 'compression'
import favicon from 'serve-favicon'
import acceptLanguage from 'accept-language'
import React from 'react'
import ReactDOMServer from 'react-dom/server'
import enLocaleData from 'react-intl/locale-data/en'
import ptLocaleData from 'react-intl/locale-data/pt'
import { addLocaleData, IntlProvider } from 'react-intl'
import { match, RouterContext } from 'react-router'
import { createStore } from 'redux'
import { Provider } from 'react-redux'
import Handlebars from 'handlebars'
import fs from 'fs'
import enMessages from './app/locales/en-US.json'
import ptMessages from './app/locales/pt-BR.json'
import rootReducer from './app/js/reducers/index.jsx'
import { getInitialState, composeMiddleware } from './app/js/store.jsx'
const port = process.env.PORT || 3000
const baseTemplate = fs.readFileSync('./public/index.html')
const template = Handlebars.compile(`${baseTemplate}`)
import {Routes} from './app/js/client-app.jsx'
const routes = Routes

const app = express()

app.use('/public', express.static('./public'))

const locales = []

locales['en-us'] = enMessages
locales['pt-br'] = ptMessages

addLocaleData(enLocaleData)
addLocaleData(ptLocaleData)

Handlebars.registerHelper('json', (context) => {
  return JSON.stringify(context)
})

app.use(compression({ threshold: 0 }))
app.use(favicon(path.join(__dirname, '/public/favicon.ico')))
app.use((req, res) => {
  let locale = 'en-us'
  const reqLocales = acceptLanguage.parse(req.headers['accept-language'])

  for (let i = 0; i < reqLocales.length; i++) {
    if (reqLocales[i].language !== null && reqLocales[i].region !== null) {
      locale = reqLocales[i].value
      break
    }
  }

  const messages = locales[locale.toLowerCase()]

  match({
    routes: routes,
    location: req.url
  }, (error, redirectLocation, renderProps) => {
    if (error) {
      res.status(500).send(error.message)
    } else if (redirectLocation) {
      res.redirect(302, redirectLocation.pathname + redirectLocation.search)
    } else if (renderProps) {
      const initialState = getInitialState()
      const { params, location } = renderProps

      if (Object.keys(params).indexOf('station') >= 0 && Object.keys(params).indexOf('topic') >= 0) {
        const slug = params.topic
        fetch.get(`topics/${slug}`).then((topic) => {
          initialState.topicsReducer.topic = topic.data
          initialState.appReducer.modal = true

          if (topic.data.embed && !topic.data.embed.isNativeVideo && topic.data.embed.provider_name !== 'YouTube') {
            initialState.topicsReducer.isEmbedCardLoading = true
          }
          sendToClient(req, res, locale, messages, renderProps, topic.data, initialState)
        }).catch(err => {
          res.redirect(302, req.protocol + '://' + req.get('host'))
          console.error('Topic not found', err)
        })
      } else if (Object.keys(params).indexOf('event') >= 0 && Object.keys(params).indexOf('topic') >= 0 && location.pathname.indexOf('highlights') === -1) {
        const slug = params.topic
        fetch.get(`topics/${slug}`).then((topic) => {
          initialState.topicsReducer.topic = topic.data
          initialState.appReducer.modal = true
          sendToClient(req, res, locale, messages, renderProps, topic.data, initialState)
        })
      } else if (Object.keys(params).indexOf('event') >= 0 && location.pathname.indexOf('highlights') === -1) {
        const slug = params.event
        fetch.get(`events/${slug}`).then((event) => {
          let newEvent = Object.assign({}, event.data)
          newEvent.ogType = 'event'
          sendToClient(req, res, locale, messages, renderProps, newEvent, initialState)
        })
      } else if (Object.keys(params).indexOf('event') >= 0 && location.pathname.indexOf('highlights') >= 0) {
        const slug = params.event
        fetch.get(`events/${slug}/highlights`).then((eventHighlights) => {
          initialState.eventsReducer.eventHighlights = eventHighlights.data
          let topic = {}
          if (eventHighlights.data.topics && eventHighlights.data.topics.length > 0) {
            let currentTopicIndex
            if (Object.keys(params).indexOf('topic') >= 0) {
              const topicSlug = params.topic
              topic = eventHighlights.data.topics.find((topic, index) => {
                currentTopicIndex = index
                return topic.slug === topicSlug
              })

              initialState.eventsReducer.highlightsSource = 'topic'
            } else {
              topic = eventHighlights.data.topics[0]
              currentTopicIndex = 0
              initialState.eventsReducer.highlightsSource = 'highlights'
            }
            initialState.eventsReducer.eventHighlightsTopic = topic
            initialState.eventsReducer.currentEventHighlightTopic = currentTopicIndex
            initialState.eventsReducer.showHighlightsModal = true
          }

          sendToClient(req, res, locale, messages, renderProps, topic, initialState)
        })
      } else {
        sendToClient(req, res, locale, messages, renderProps, {}, initialState)
      }
    } else {
      res.status(404).send('Not found')
    }
  })
})

function sendToClient (req, res, locale, messages, renderProps, topic, initialState) {
  const store = createStore(rootReducer, initialState, composeMiddleware)
  if (!global.Intl) {
    require.ensure([
      'intl',
      'intl/locale-data/jsonp/en.js',
      'intl/locale-data/jsonp/pt.js'
    ], function (require) {
      require('intl')
      require('intl/locale-data/jsonp/en.js')
      require('intl/locale-data/jsonp/pt.js')
    })
  }

  const body = ReactDOMServer.renderToString(
    React.createElement(IntlProvider, { locale, messages },
      React.createElement(Provider, { store },
        React.createElement(RouterContext, renderProps)
      )
    )
  )

  const og = {}

  if (topic.ogType === 'event') {
    og.title = topic.name
    og.description = topic.description
    og.url = req.protocol + '://' + req.get('host') + req.originalUrl
    og.image = topic.coverImage
    og.type = 'video.other'
  } else if (topic.embed) {
    og.title = topic.title
    og.description = topic.embed ? topic.embed.description : null
    og.url = req.protocol + '://' + req.get('host') + req.originalUrl
    og.image = topic.image
    og.type = 'video.other'
  }

  res.status(200).send(template({
    initialState: JSON.stringify(initialState),
    body,
    og_title: og.title || 'Stationfy - Highlights from Sports Events',
    og_description: og.description || 'Best moments from your favorite sports.',
    og_site_name: 'Stationfy',
    og_url: og.url || 'http://stationfy.com',
    og_image: og.image || 'http://stnfy-imgs-prd.s3-website-us-west-2.amazonaws.com/stationfy_logo.jpg',
    og_type: og.type || 'website',
    fb_app_id: '145537902308913'
  }))
}

console.log('listening on ' + port)
app.listen(port)
