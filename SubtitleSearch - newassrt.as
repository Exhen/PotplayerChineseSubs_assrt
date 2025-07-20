/*
	subtitle search by assrt (Fixed Version)
	Based on official API documentation: https://secure.assrt.net/api/doc
*/
 
// string GetTitle() 																-> get title for UI
// string GetVersion																-> get version for manage
// string GetDesc()																	-> get detail information
// string GetLoginTitle()															-> get title for login dialog
// string GetLoginDesc()															-> get desc for login dialog
// string ServerCheck(string User, string Pass) 									-> server check
// string ServerLogin(string User, string Pass) 									-> login
// string GetLanguages()															-> get support language
// string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)			-> search subtitle bu web browser
// array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)	-> search subtitle
// string SubtitleDownload(string id)												-> download subtitle
 
string Token;

// Language mapping based on API response
string convertLangFromAPI(JsonValue langObj)
{
    if (!langObj.isObject()) {
        return "";
    }
    
    string desc = langObj["desc"].asString();
    JsonValue langlist = langObj["langlist"];
    
    // Check for specific language flags
    if (langlist.isObject()) {
        if (langlist["langdou"].asBool()) {
            if (desc.findFirst("双语") >= 0) {
                return "zh-CN"; // Assume Chinese for bilingual
            }
            return "zh-CN"; // Chinese
        }
        if (langlist["langkor"].asBool()) {
            return "ko"; // Korean
        }
        if (langlist["langeng"].asBool()) {
            return "en"; // English
        }
        if (langlist["langjap"].asBool()) {
            return "ja"; // Japanese
        }
    }
    
    // Fallback to description parsing
    if (desc.findFirst("简") >= 0 || desc.findFirst("中") >= 0) {
        return "zh-CN";
    }
    if (desc.findFirst("繁") >= 0) {
        return "zh-TW";
    }
    if (desc.findFirst("英") >= 0) {
        return "en";
    }
    if (desc.findFirst("日") >= 0) {
        return "ja";
    }
    if (desc.findFirst("韩") >= 0) {
        return "ko";
    }
    
    return "";
}

string UrlComposeQuery(string &host, const string &in path, dictionary &in querys)
{
	string ret = host + path + "?";
	const array<string> keys = querys.getKeys();
	for (int i = 0, len = keys.size(); i < len; i++){
		if (i > 0 ){
			ret += "&";
		}
		ret += keys[i] + "=" + HostUrlEncode(string(querys[keys[i]]));
	}
	return ret;
}

string HtmlSpecialCharsDecode(string str)
{
	str.replace("&amp;", "&");
	str.replace("&quot;", "\"");
	str.replace("&#039;", "'");
	str.replace("&lt;", "<");
	str.replace("&gt;", ">");
	str.replace("&rsquo;", "'");
	return str;
}

// Use working API endpoint (backup domain with HTTP)
string API_URL = "http://api.makedie.me";

// Updated language table based on common usage
array<array<string>> LangTable =
{
	{ "en", "English" },                              
	{ "zh-TW", "Traditional Chinese" },                                     
	{ "zh-CN", "Simplified Chinese" },
	{ "ja", "Japanese" },
	{ "ko", "Korean" }                         
};

string GetTitle()
{
	return "射手网(修复版)";
}

string GetVersion()
{
	return "3.0";
}

string GetDesc()
{
	return "基于官方API文档修复的射手网字幕搜索插件";
}

string GetLoginTitle()
{
	return "API Token";
}

string GetLoginDesc()
{
	return "请输入射手网的API Token（在用户面板中获取）";
}

string GetLanguages()
{
	string ret = "";
	for(int i = 0, len = LangTable.size(); i < len; i++)
	{
		string lang = LangTable[i][0];
		
		if (!lang.empty())
		{
			if (ret.empty()) ret = lang;
			else ret = ret + "," + lang;
		}
	}
	return ret;
}

string ServerCheck(string User, string Pass)
{
	return ServerLogin(User, Pass);
}

string ServerLogin(string User, string Pass)
{
    Token = Pass;
    
    // Test API with quota check
    string testUrl = UrlComposeQuery(API_URL, "/v1/user/quota", {
        {"token", Token}
    });
    
    string response = HostUrlGetString(testUrl);
    JsonValue json;
    JsonReader jsonR;
    
    if (jsonR.parse(response, json))
    {
        if (json["status"].isInt())
        {
            int status = json["status"].asInt();
            if (status == 0)
            {
                int quota = json["user"]["quota"].asInt();
                return "登录成功！当前配额: " + formatInt(quota) + " 次/分钟";
            }
            else
            {
                // Handle specific error codes
                if (status == 20001) {
                    return "错误：Token无效";
                } else if (status == 30900) {
                    return "错误：配额超限";
                } else {
                    return "错误：状态码 " + formatInt(status);
                }
            }
        }
    }
    return "错误：无法连接到API服务器";
}

string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)
{
	string title = HtmlSpecialCharsDecode(string(MovieMetaData["title"]));

	// Handle TV series with season and episode
	if(MovieMetaData.exists("seasonNumber")){
		string season = string(MovieMetaData["seasonNumber"]);
		if(season.length() < 2){
			season = '0' + season;
		}
		if(MovieMetaData.exists("episodeNumber")){
			string episode = string(MovieMetaData["episodeNumber"]);
			if(episode.length() < 2){
				episode = '0' + episode;
			}
			title = title + " S" + season + 'E' + episode;
		}
		else{
			title = title + " S" + season;
		}
	}

	// Build search URL with correct parameters according to API doc
	// Use filelist=1 to get file information when available
	string finalURL = UrlComposeQuery(API_URL, '/v1/sub/search', {
		{"token", Token},
		{"q", title},
		{"cnt", "15"},
		{"pos", "0"},
		{"filelist", "1"}
	});
	return finalURL;
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;

	// Skip Blu-ray playlist and transport stream files
	array<string> MovieFileNameSplit = MovieFileName.split(".");
	if(MovieFileNameSplit[MovieFileNameSplit.length()-1] == "mpls" ||
	   MovieFileNameSplit[MovieFileNameSplit.length()-1] == "m2ts"){
		return ret;
	}

	string baseURL = SubtitleWebSearch(MovieFileName, MovieMetaData);

	// Pagination loop
	for(int page = 0; ; page++){
		string searchURL = baseURL;
		if (page > 0) {
			searchURL = searchURL.replace("pos=0", "pos=" + formatInt(page * 15));
		}

		string response = HostUrlGetString(searchURL);
		JsonReader Reader;
		JsonValue Root;

		if (Reader.parse(response, Root) && Root.isObject())
		{
			if (Root["status"].isInt()){
				int status = Root["status"].asInt();
				if (status == 0) {
					JsonValue subs = Root["sub"]["subs"];
					if (subs.isArray()){
						int subsCount = subs.size();

						for(int i = 0; i < subsCount; i++){
							JsonValue subItem = subs[i];

							// Check if this subtitle has filelist (multiple files)
							if (subItem["filelist"].isArray() && subItem["filelist"].size() > 0) {
								JsonValue filelist = subItem["filelist"];
								for (int f = 0; f < filelist.size(); f++) {
									dictionary item;
									JsonValue fileItem = filelist[f];

									// Use subtitle ID + file index for multi-file archives
									item["id"] = formatInt(subItem["id"].asInt()) + "￥" + formatInt(f);
									item["title"] = subItem["native_name"].asString();

									// Get language from API response
									if (subItem["lang"].isObject()) {
										item["lang"] = convertLangFromAPI(subItem["lang"]);
									} else {
										item["lang"] = "";
									}

									// Get format from file name or subtype
									string fileName = fileItem["f"].asString();
									array<string> fileNameParts = fileName.split(".");
									if (fileNameParts.size() > 1) {
										item["format"] = fileNameParts[fileNameParts.size()-1];
									} else {
										item["format"] = subItem["subtype"].asString();
									}

									item["fileName"] = fileName;

									// Store detail URL for download
									item["url"] = UrlComposeQuery(API_URL, "/v1/sub/detail", {
										{"token", Token},
										{"id", formatInt(subItem["id"].asInt())}
									});

									ret.insertLast(item);
								}
							} else {
								// Single file subtitle
								dictionary item;

								item["id"] = formatInt(subItem["id"].asInt());
								item["title"] = subItem["native_name"].asString();

								// Get language from API response
								if (subItem["lang"].isObject()) {
									item["lang"] = convertLangFromAPI(subItem["lang"]);
								} else {
									item["lang"] = "";
								}

								// Get format from API response
								item["format"] = subItem["subtype"].asString();

								// Use videoname if available, otherwise use native_name
								if (subItem["videoname"].isString()) {
									item["fileName"] = subItem["videoname"].asString();
								} else {
									item["fileName"] = subItem["native_name"].asString();
								}

								// Store detail URL for download
								item["url"] = UrlComposeQuery(API_URL, "/v1/sub/detail", {
									{"token", Token},
									{"id", formatInt(subItem["id"].asInt())}
								});

								ret.insertLast(item);
							}
						}

						// If we got less than 15 results, we've reached the end
						if(subsCount < 15){
							break;
						}
					}
					else{
						break;
					}
				}
				else{
					// Handle API errors
					if (status == 101) {
						// Search keyword too short
						break;
					} else if (status == 30900) {
						// Rate limit exceeded
						break;
					}
					break;
				}
			}
			else{
				break;
			}
		}
		else{
			break;
		}
	}
	return ret;
}

string SubtitleDownload(string id)
{
	// Parse subtitle ID (may contain file index for multi-file archives)
	array<string> idParts = id.split("￥");
	string subtitleId = idParts[0];
	int fileIndex = 0;

	if (idParts.size() > 1) {
		fileIndex = parseInt(idParts[1]);
	}

	// Get subtitle details using the correct API endpoint
	string detailURL = UrlComposeQuery(API_URL, "/v1/sub/detail", {
		{"token", Token},
		{"id", subtitleId}
	});

	string response = HostUrlGetString(detailURL);
	JsonReader Reader;
	JsonValue Root;

	if (Reader.parse(response, Root) && Root.isObject())
	{
		if (Root["status"].isInt()){
			int status = Root["status"].asInt();
			if (status == 0) {
				JsonValue subs = Root["sub"]["subs"];
				if (subs.isArray() && subs.size() > 0) {
					JsonValue subDetail = subs[0];

					// Check if this subtitle has multiple files (filelist)
					if (subDetail["filelist"].isArray() && subDetail["filelist"].size() > 0) {
						JsonValue filelist = subDetail["filelist"];
						if (fileIndex < filelist.size()) {
							// Download specific file from archive
							string fileURL = filelist[fileIndex]["url"].asString();
							return HostUrlGetString(fileURL);
						} else if (filelist.size() > 0) {
							// Default to first file if index is out of range
							string fileURL = filelist[0]["url"].asString();
							return HostUrlGetString(fileURL);
						}
					}

					// Single file subtitle - use main download URL
					if (subDetail["url"].isString()) {
						string downloadURL = subDetail["url"].asString();
						return HostUrlGetString(downloadURL);
					}
				}
			}
			else {
				// Handle API errors
				if (status == 20900) {
					// Subtitle not found
					return "";
				} else if (status == 30900) {
					// Rate limit exceeded
					return "";
				}
			}
		}
	}

	return "";
}
