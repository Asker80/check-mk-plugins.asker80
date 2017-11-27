#!/usr/bin/env python
# -*- encoding: utf-8; py-indent-offset: 4 -*-

# Put this file into /omd/sites/<sitename>/local/share/check_mk/web/plugins/wato/
# to be able to create WATO rules under 'Parameters for discovered services/Applications, Processes & Services/Egais UTM ...'

register_check_parameters(
    subgroup_applications,
    "egais_utm_unsent_docs_settings",
    _("Egais UTM Unsent Docs"),
    Dictionary(
        elements = [
            ( "levels",
                Tuple(
                    title = _("Egais UTM unsent docs age"),
	                elements = [
	                    Integer(title = "Warning at", default_value = 15, unit = u"minutes"),
	                    Integer(title = "Critical at", default_value = 30, unit = u"minutes"),
                    ],
                ),
            ),
        ],
        optional_keys = False,
    ),
    None,
#    TextAscii(
#        title = _("Description (should always be empty)"),
#        allow_empty = True
#    ),
    match_type = 'dict',
)

register_check_parameters(
    subgroup_applications,
    "egais_utm_cert_settings",
    _("Egais UTM Certificates"),
    Dictionary(
        elements = [
            ( "levels",
                Tuple(
                    title = _("Egais UTM Certificate Age"),
	                elements = [
	                    Integer(title = "Warning at or below", default_value = 30, unit = u"days"),
	                    Integer(title = "Critical at or below", default_value = 15, unit = u"days"),
                    ],
                ),
            ),
        ],
        optional_keys = False,
    ),
    TextAscii(
        title = _("Service Descriptions"),
        allow_empty = True
    ),
    match_type = 'dict',
)
