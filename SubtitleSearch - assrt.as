/*
	subtitle search by assrt
*/
 
// string GetTitle() 																-> get title for UI
// string GetVersion																-> get version for manage
// string GetDesc()																	-> get detail information
// string GetLoginTitle()															-> get title for login dialog
// string GetLoginDesc()															-> get desc for login dialog
// string GetUserText()																-> get user text for login dialog
// string GetPasswordText()															-> get password text for login dialog
// string ServerCheck(string User, string Pass) 									-> server check
// string ServerLogin(string User, string Pass) 									-> login
// void ServerLogout() 																-> logout
// string GetLanguages()															-> get support language
// string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)			-> search subtitle bu web browser
// array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)	-> search subtitle
// string SubtitleDownload(string id)												-> download subtitle
// string GetUploadFormat()															-> upload format
// string SubtitleUpload(string MovieFileName, dictionary MovieMetaData, string SubtitleName, string SubtitleContent)	-> upload subtitle
 
string Token;

uint64 GetHash(string FileName)
{
	int64 size = 0;
	uint64 hash = 0;
	uintptr fp = HostFileOpen(FileName);

	if (fp != 0)
	{
		size = HostFileLength(fp);
		hash = size;
		
		for (int i = 0; i < 65536 / 8; i++) hash = hash + HostFileReadQWORD(fp);
		
		int64 ep = size - 65536;
		if (ep < 0) ep = 0;
		HostFileSeek(fp, ep, 0);
		for (int i = 0; i < 65536 / 8; i++) hash = hash + HostFileReadQWORD(fp);
		
		HostFileClose(fp);
	}
	
	return hash;
}


void AssignItem(dictionary &dst, JsonValue &in src, string dst_key, string src_key = "")
{
	if (src_key.empty()) src_key = dst_key;
	if (src[src_key].isString()) dst[dst_key] = src[src_key].asString();
	else if (src[src_key].isInt64()) dst[dst_key] = src[src_key].asInt64();	
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

string API_URL = "https://api.assrt.net";

array<array<string>> LangTable =
{
	{ "en", "English" },                              
	{ "zh", "Chinese" },                                     
	{ "zh", "Mandarin" }                         
};

string GetTitle()
{
	return "射手(伪)";
}

string GetVersion()
{
	return "1";
}

string GetDesc()
{
	return "https://secure.assrt.net/usercp.php";
}

string GetLoginTitle()
{
	return "Token";
}

string GetLoginDesc()
{
	return "账户随便填，密码填assrt的token";;
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
	string ret = HostUrlGetString(API_URL);
	
	if (ret.empty()) return "fail";
	return "200 OK";
}

string ServerLogin(string User, string Pass)
{

	string r = HostUrlGetString(API_URL+'/v1/sub/search?token=' + Pass + '&q=颐和园&cnt=1&pos=0');
	string ret;
	JsonValue json;
	JsonReader jsonR;
	if (jsonR.parse(r,json))
	{
		if(json["status"].asString()=='0')
		{
			Token = Pass;
			return "成功："+Token;
		}
		else{
			return "错误："+json["errmsg"].asString();
		}
	}

	return "错误：无法连接";
}


string SubtitleWebSearch(string MovieFileName, dictionary MovieMetaData)
{
	string title = HtmlSpecialCharsDecode(string(MovieMetaData["title"]));


	if(MovieMetaData.exists("seasonNumber")){
		string season=string(MovieMetaData["seasonNumber"]);
		
		if(season.length()<2){
			season='0'+season;
		}
		if(MovieMetaData.exists("episodeNumber")){
			string episode=string(MovieMetaData["episodeNumber"]);
			if(episode.length()<2){
				episode='0'+episode;
			}
			title=title+" S"+season+'E'+episode;
		}
		else{
			title=title+" S"+season;
		}
		
	}



	string finalURL = UrlComposeQuery(API_URL, '/v1/sub/search', {
		{"token", Token},
		{"q", title},
		{"is_file", '1'},
		{"no_muxer", '1'}
	});
	return finalURL;
	
}

array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;

	string finalURL = SubtitleWebSearch(MovieFileName, MovieMetaData);
	for(int j=0;;j++){
		string URL=UrlComposeQuery(finalURL,'',{{"pos",j}});
		string json = HostUrlGetString(URL);
		JsonReader Reader;
		JsonValue Root;

		if (Reader.parse(json, Root) && Root.isObject())
		{
			if (Root["status"].isInt()){
				int status = Root["status"].asInt();
				if (status == 0) {
					JsonValue subs = Root["sub"]["subs"];
					if (subs.isArray()){
						for(int i = 0, len = subs.size(); i < len; i++){
							dictionary item;
							AssignItem(item, subs[i], "id");
							AssignItem(item, subs[i], "title", "native_name");
							AssignItem(item, subs[i], "fileName", "videoname");
							AssignItem(item, subs[i], "format", "subtype");
							JsonValue langlist = subs[i]["lang"]["langlist"];
							item["lang"] = "zht";
							if(langlist["langchs"].asBool()){
								item["lang"] = "zhs";
							}
							if(!(langlist["langdou"].asBool()||langlist["langcht"].asBool()||langlist["langchs"].asBool())){
								item["lang"] = "eng";
								if(langlist.size()<=3){
									item["lang"] = "zh";
								}
								if(langlist["lagnkor"].asBool()){
									item["lang"] = "ko";
								}
								if(langlist["langjap"].asBool()){
									item["lang"] = "ja";
								}
							}
							ret.insertLast(item);
						}
						if(subs.size()<=15){
							break;
						}
					}else{
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
	}
	
	
	return ret;
}

string SubtitleDownload(string id)
{
	string api = UrlComposeQuery(API_URL, "/v1/sub/detail", {
		{"token", Token},
		{"id", id}
	});

	string json = HostUrlGetString(api);
	JsonReader Reader;
	JsonValue Root;
	
	if (Reader.parse(json, Root) && Root.isObject())
	{
		if (Root["status"].isInt()){
			int status = Root["status"].asInt();

			if (status == 0) {
				JsonValue subs = Root["sub"]["subs"];	


				if (subs.isArray()){
					JsonValue subDetail = subs[0];

					if (subDetail.isObject()){

						JsonValue url = subDetail["filelist"][0]["url"];
													
						if (url.isString())
						{
							return HostUrlGetString(url.asString());
						}
					}					
				}
			}
		}
	}

	return "";
}
