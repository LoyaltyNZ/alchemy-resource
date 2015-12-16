# # Bam
#
# Bam describes the format and content for different error types in Alchemy Resource
# (in homage to [Boom](https://www.npmjs.com/package/boom)).
# It bases the structure on the [Hoodoo project](https://github.com/LoyaltyNZ/hoodoo),
# which described the meaning of the messages.

# It reuses the UUIDs from Alchemy Ether as reference IDs
generateUUID = require("alchemy-ether").generateUUID

Bam = {}

# `build_bam_error` builds an error as specified in [Hoodoo documentation](https://github.com/LoyaltyNZ/hoodoo/tree/master/docs/api_specification#errors.resource).
# This includes the return type and `bam: true` so that the framework can be certain of this structure.
build_bam_error = (context, status_code, errors) ->
  {
    bam: true
    status_code: status_code
    headers: {'Content-Type': 'application/json; charset=utf-8'}
    body:   {
      kind:           "Errors",
      id:             generateUUID()
      created_at:     (new Date()).toISOString(),
      interaction_id: context.interaction_id
      errors: [errors]
    }
  }


# `joi_validation_error` takes an error from the JSON validation library [Joi](https://www.npmjs.com/package/joi)
#  and formats it into a Alchemy Resource error
Bam.joi_validation_error = (context, joi_error) ->
  errors = []
  for deet in joi_error.details
    switch deet.type
      when 'any.required'
        errors.push {
          code: "generic.required_field_missing"
          message: deet.message
        }
      when 'object.missing'
        errors.push {
          code: "generic.required_field_missing"
          message: deet.message
        }
      when 'string.regex.base'
        errors.push {
          code: "generic.invalid_string"
          message: deet.message
        }
      else
        errors.push {
          code: "generic.unknown"
          message: deet.message
          reference: deet.type
        }

  build_bam_error(context, 422, errors)


Bam.malformed_body = (context) ->
  build_bam_error(context, 422, [{code: "platform.malformed", message: "malformed body data"}])

Bam.method_not_allowed = (context) ->
  build_bam_error(context, 405, [{code: "platform.method_not_allowed", message: "not allowed"}])

Bam.no_interaction_id = (context) ->
  build_bam_error(context, 422, [{code: "platform.no_interaction_id", message: "#{message}"}])

Bam.required_field_missing = (context, message) ->
  build_bam_error(context, 422, [{code: "generic.required_field_missing", message: "no interaction id"}])

Bam.not_allowed = (context) ->
  build_bam_error(context, 403, [{code: "platform.forbidden", message: "not allowed"}])

Bam.not_found = (context, resource) ->
  build_bam_error(context, 404, [{code: "platform.not_found", message: "#{resource} not found"}])

Bam.exists = (context, resource) ->
  build_bam_error(context, 422, [{code: "platform.exists", message: "#{resource} already exists"}])

Bam.timeout_error = (context, timeout) ->
  build_bam_error(context, 408, [{code: 'platform.timeout', message: "Request timeout (#{timeout}ms)"}])

Bam.error = (context, err) ->
  error = {
    code: 'platform.fault'
    message: 'An unexpected error occurred'
  }
  if process.env.NODE_ENV in ['development', 'test', 'staging']
    error.stack = err.stack

  build_bam_error(context, 408, [error])

module.exports = Bam