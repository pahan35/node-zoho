contentDisposition = require('content-disposition')
xml2js = require("xml2js")
_ = require('underscore')

class Response

  # instance values
  message:   null
  type:      null
  data:      null
  code:      null
  _response: null
  _data:     null

  # constuctor
  constructor: (@_response) ->
    if @_response is undefined
      throw new Error('Requires response')
    return

  isError: () ->
    if @code != null
      return true
    return false

  parseFile: (buffer, cb) ->
    if not buffer and Buffer.isBuffer(buffer)
      throw new Error('Requires buffer')
    if not cb
      throw new Error('Requires callback')
    disposition = contentDisposition.parse(@_response.headers['content-disposition'])
    filename = disposition.parameters.filename
    @_data = @data = {filename: filename, buffer: buffer}
    return cb(null, @)

  parseBody: (body, cb) ->
    if not body
      throw new Error('Requires body')
    if not cb
      throw new Error('Requires callback')

    @_data = body
    xml2js.parseString @_data, (err, data) =>
      if err
        return cb(err, null)
      else
        @data = data
        if @data?.response?.error
          error = @parseError(@data.response.error)
          @code = error.code
          @message = error.message

          return cb({code: @code, message: @message}, @)

        else if @data?.response?.nodata
          error = @data.response.nodata

          if _.isArray(error)
            error = _.first(error)

          if error?.code
            @code = error.code
            if _.isArray(@code)
              @code = _.first(@code)

          if error?.message
            @message = error.message
            if _.isArray(@message)
              @message = _.first(@message)
          else
            @message = "Unknown Error"

          return cb(null,@)

        else

          if @data?.response?.result
            result = @data.response.result
            if _.isArray(result) and result.length == 1
              record = _.first(result)
              if record?.row
                @data = for row in record.row
                  if row?.error
                    @parseError(row.error)
                  else if row?.success
                    @parseSuccess(row.success)

              else
                if record?.message
                  @message = record.message

                if record?.recorddetail
                  @data = record.recorddetail
                else
                  @data = record

          else if @data?.response?.success
            success = @data.response.success

            record = @parseSuccess(success)
            @code = record.code
            @data = record.data
            @message = record.message

          return cb(null, @)

  parseError: (error)  ->
    if _.isArray(error)
      error = _.first(error)

    if error?.code
      code = error.code

    if error?.message
      message = error.message
    else
      message = "Unknown Error"

    return {code, message}

  parseSuccess: (success) ->
    if _.isArray(success)
      success = _.first(success)

    if success?.code
      code = success.code
      if _.isArray(code)
        code = _.first(code)

    if success?.message
      message = success.message
      if _.isArray(message)
        message = _.first(message)
    else
      message = "Unknown Success"

    data = if success?.details then success.details else {'success': {'code': code, 'message': message}}

    return {code, data, message}


module.exports = Response
