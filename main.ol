from protocols.http import DefaultOperationHttpRequest
from console import Console
from string-utils import StringUtils
from mustache import Mustache
from reflection import Reflection
from runtime import Runtime
from file import File
from values import Values
from @jolie.leonardo import WebFiles
from @jolie.commonmark import CommonMark

/// Operations offered through the web interface
interface WebInterface {
RequestResponse:
	/// Generic GET request
	get( DefaultOperationHttpRequest )( undefined )
}

type NewsEntry {
	text: string
	datetime: string
	file?: string
}

/// Type of the data needed by index.html
type IndexData {
	jolieVersion: string //< The version of the Jolie interpreter running this service
	people*: undefined
}

/// Type of the data for news.html
type NewsData {
	news {
		items*: NewsEntry
	}
}

/// Type of the data needed by /research/index.html
type ResearchIndexData {
	grants {
		items*: undefined
	}
}

/// A single ACP seminar talk
type SeminarTalk {
  title?: string
  from: string
  to: string
  location: string
  map?: string
  videomeeting?: string
  speaker: string
  abstract?: string
  pubDate: string
  humanReadableDatetime: string
  guid: int
}

/// Scheduled ACP seminar talks
type SeminarData {
  seminar {
    items*: SeminarTalk
  }
}

/// Operations that generate the data needed by the Mustache templates
interface MustacheOperations {
RequestResponse:
	/// Gets the data needed by the index.html page
	index( void )( IndexData ),

	/// Gets the data needed by the /research/index.html page
	researchIndex( void )( ResearchIndexData ),

	/// Gets the data needed by the news.html page
	news( void )( NewsData ),

	/// Gets the data needed by the seminar pages
	seminar( void )( SeminarData ),
}

service Main {
	execution: concurrent

	embed Console as console
	embed WebFiles as webFiles
	embed StringUtils as stringUtils
	embed Mustache as mustache
	embed Runtime as runtime
	embed Reflection as reflection
	embed File as file
  embed Values as values
	embed CommonMark as commonMark

	inputPort WebInput {
		location: "socket://localhost:8080"
		protocol: http {
			format -> httpParams.format
			contentType -> httpParams.contentType
			cacheControl.maxAge -> httpParams.cacheControl.maxAge
			redirect -> redirect
			statusCode -> statusCode
			default.get = "get"
		}
		interfaces: WebInterface
	}

	inputPort Local {
		location: "local"
		interfaces: MustacheOperations
	}

	outputPort self {
		interfaces: MustacheOperations
	}

	init {
		global.wwwDir = "web"
		global.templatesDir = "templates"
		format = "html"
		getLocalLocation@runtime()( self.location )

		dataBindings

		println@console( "Server started at " + global.inputPorts.WebInput.location )()
	}

	// Define your data bindings for Mustache templates here
	define dataBindings {
		// Page index.html gets data from operation index
		global.dataBindings.("/index.html") = "index"
		global.dataBindings.("/research/index.html") = "researchIndex"
		global.dataBindings.("/news.html") = "news"
		global.dataBindings.("/seminar/index.html") = "seminar"
		global.dataBindings.("/seminar/index.xml") = "seminar"
	}

	main {
		[ get( request )( response ) {
			scope( get ) {
				install(
					FileNotFound =>
						statusCode = 404,
					MovedPermanently =>
						redirect = get.MovedPermanently
						statusCode = 301
				)
				// If the request is for a news page, add '.md' to the resource path
				if( match@stringUtils( request.operation { regex = ".*news/([^/\\.]+)" } ) ) {
					request.operation += ".md"
				}

				get@webFiles( {
					target = request.operation
					wwwDir = global.wwwDir
				} )( getResult )
				httpParams -> getResult.httpParams

				// If it's a markdown file, render it
				if( endsWith@stringUtils( getResult.path { suffix = ".md" } ) ) {
					getResult.httpParams.format = "html"
					getResult.httpParams.contentType = "text/html"
					// getResult.content = string( getResult.content )
					getResult.content = render@commonMark( string( getResult.content ) )
				}

				substring@stringUtils( getResult.path { begin = length@stringUtils( global.wwwDir ) } )( webPath )
				// By default, Mustache and Markdown are activated only for html pages
				if( getResult.httpParams.format == "html" ) {
					if( startsWith@stringUtils( getResult.content { prefix = "<!--CommonMark-->" } ) ) {
						render@commonMark( getResult.content )( getResult.content )
					}

					if( is_defined( global.dataBindings.(webPath) ) ) {
						invoke@reflection( {
							operation = global.dataBindings.(webPath)
							outputPort = "self"
						} )( data )
					} else {
						data << {}
					}
					render@mustache( {
						template -> getResult.content
						data -> data
						dir = global.templatesDir
					} )( response )
				} else {
					response -> getResult.content
				}
			}
		} ]

		[ index()( response ) {
			readFile@file( { filename = "data/people.json", format = "json" } )( response.people )
			getVersion@runtime()( response.jolieVersion )
		} ]

		[ researchIndex()( response ) {
			readFile@file( { filename = "data/grants.json", format = "json" } )( response.grants )
		} ]

		[ news()( response ) {
			readFile@file( { filename = "data/news.yaml", format = "yaml" } )( response.news )
			for( item in response.news.items ) {
				split@stringUtils( item.datetime { regex = "T" } )( s )
             	item.datetime = s.result[0]
				render@commonMark( item.text )( item.text )
			}
		} ]

		[ seminar()( response ) {
			readFile@file( { filename = "data/seminar.json", format = "json" } )( response.seminar )
			for ( i in response.seminar.items) {
        i.guid = hashCode@values( i )
        // getDateTimeValues does not seem to work?
        i.humanReadableDatetime = fmt@stringUtils( "{y}/{m}/{d}, {hf}:{mf}-{ht}:{mt}" {
        y = substring@stringUtils( i.from { begin = 0, end = 4 } ),
        m = substring@stringUtils( i.from { begin = 4, end = 6 } ),
        d = substring@stringUtils( i.from { begin = 6, end = 8 } ),
        hf = substring@stringUtils( i.from { begin = 9, end = 11 } ),
        mf = substring@stringUtils( i.from { begin = 11, end = 13 } ),
        ht = substring@stringUtils( i.to { begin = 9, end = 11 } ),
        mt = substring@stringUtils( i.to { begin = 11, end = 13 } ),
        } )
      }
		} ]
	}
}
