/*
    Copyright (C) 2010  ABRT team
    Copyright (C) 2010  RedHat Inc

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/
#ifndef RHTICKET_H_
#define RHTICKET_H_

#include "plugin.h"
#include "reporter.h"

class CReporterRHticket: public CReporter
{
	private:
		bool m_ssl_verify;
		char *m_strata_url;
		char *m_login;
		char *m_password;

	public:
		CReporterRHticket();
		virtual ~CReporterRHticket();

		virtual std::string Report(const map_crash_data_t& pCrashData,
				const map_plugin_settings_t& pSettings,
				const char *pArgs);

		virtual void SetSettings(const map_plugin_settings_t& pSettings);
		virtual const map_plugin_settings_t& GetSettings();
};

#endif