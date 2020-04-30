/*
	subtitle search by assrt
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

string convertLang(string lang)
{
    if(lang.findFirst("简")>=0||lang.findFirst("chs")>=0){
        return "zh-CN";
    }else{
        if(lang.findFirst("繁")>=0||lang.findFirst("cht")>=0){
          return "zh-TW";
        }
        else{
            if(lang.findFirst("英")>=0||lang.findFirst("eng")>=0){
                return "en";
            }else{
                if(lang.findFirst("日")>=0||lang.findFirst("jap")>=0){
                    return "ja";
                }else{
                    if(lang.findFirst("韩")>=0||lang.findFirst("ko")>=0){
                        return "ko";
                    }
                }
            }
        }
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
string API_URL = "https://api.assrt.net";
array<array<string>> LangTable =
{
	{ "en", "English" },                              
	{ "zh-TW", "Chinese" },                                     
	{ "zh-CN", "Mandarin" }                         
};
string GetTitle()
{
	return "射手(伪)";
}
string GetVersion()
{
	return "2.0";
}
string GetDesc()
{
	return "https://github.com/Exhen/PotplayerChineseSubs";
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
	return ServerLogin(User,Pass);
}
string ServerLogin(string User, string Pass)
{
    Token = Pass;
	string r = HostUrlGetString(API_URL+"/v1/sub/search?token=" + Pass + "&q=颐和园");
	JsonValue json;
	JsonReader jsonR;
	if (jsonR.parse(r,json))
	{
        // HostPrintUTF8("status: "+formatInt(json["status"].asInt()));
		if(json["status"].asInt()==0)
		{
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
		{"filelist", '1'},
		{"cnt", '15'},
		{"no_muxer", '1'}
	});
	return finalURL;
}
array<dictionary> SubtitleSearch(string MovieFileName, dictionary MovieMetaData)
{
	array<dictionary> ret;
    // HostOpenConsole();
    array<string> MovieFileNameSplit=MovieFileName.split(".");
    if(MovieFileNameSplit[MovieFileNameSplit.length()-1]=="mpls"||MovieFileNameSplit[MovieFileNameSplit.length()-1]=="m2ts"){
        return ret;
    }
	string finalURL = SubtitleWebSearch(MovieFileName, MovieMetaData);
	for(int j=0;;j++){
		string URL=finalURL+"&pos="+formatInt(j*15);
		// HostPrintUTF8(URL);
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
							if(subs[i]["filelist"].size()>0){
								for(int f=0,fLen=subs[i]["filelist"].size();f<fLen;f++){
									dictionary item;
									int id=subs[i]["id"].asInt();
									item["id"]=formatInt(id)+"￥"+formatInt(f);
									item["title"]=subs[i]["native_name"].asString();
									string fileName=subs[i]["filelist"][f]["f"].asString();
									array<string> fileNameSplit=fileName.split(".");
									string subtype=fileNameSplit[fileNameSplit.length()-1];
									string lang=fileNameSplit[fileNameSplit.length()-2];
									item["fileName"]=fileName;
									item["format"]=subtype;
									item["lang"]=convertLang(lang);
									item["url"]="http://assrt.net/xml/sub/"+formatInt(id/1000)+"/"+formatInt(id)+".xml";
									ret.insertLast(item);
								}
							}
							else{
								dictionary item;
								int id=subs[i]["id"].asInt();
								item["id"]=formatInt(id);
								item["title"]=subs[i]["native_name"].asString();
								string fileName=subs[i]["filename"].asString();
								array<string> fileNameSplit=fileName.split(".");
								string subtype=fileNameSplit[fileNameSplit.length()-1];
								string lang=fileNameSplit[fileNameSplit.length()-2];
								item["fileName"]=fileName;
								item["format"]=subtype;
								item["lang"]=convertLang(lang);
								item["url"]="http://assrt.net/xml/sub/"+formatInt(id/1000)+"/"+formatInt(id)+".xml";
								ret.insertLast(item);
							}
						}
						if(subs.size()<15){
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
	array<string> idSplit=id.split("￥");
	if(idSplit.size()>1){
		int num=parseInt(idSplit[1]);
		string api = UrlComposeQuery(API_URL, "/v1/sub/detail", {
			{"token", Token},
			{"id", idSplit[0]}
		});
		string downJson = HostUrlGetString(api);
		JsonReader downReader;
		JsonValue downRoot;
		if (downReader.parse(downJson, downRoot) && downRoot.isObject())
		{
			if (downRoot["status"].isInt()){
		        // HostPrintUTF8(downRoot["status"].asString());
				int downStatus = downRoot["status"].asInt();
				if (downStatus == 0) {
					JsonValue fSubs = downRoot["sub"]["subs"];	
					if (fSubs.isArray()){
						JsonValue subDetail = fSubs[0];
						if (subDetail.isObject()){
							if(subDetail["filelist"].size()>num){
								return HostUrlGetString(subDetail["filelist"][num]["url"].asString());
							}

						}	
					}
				}
			}
		}
	}else{
		string api = UrlComposeQuery(API_URL, "/v1/sub/detail", {
			{"token", Token},
			{"id", idSplit[0]}
		});
		string downJson = HostUrlGetString(api);
		JsonReader downReader;
		JsonValue downRoot;
		if (downReader.parse(downJson, downRoot) && downRoot.isObject())
		{
			if (downRoot["status"].isInt()){
		        // HostPrintUTF8(downRoot["status"].asString());
				int downStatus = downRoot["status"].asInt();
				if (downStatus == 0) {
					JsonValue fSubs = downRoot["sub"]["subs"];	
					if (fSubs.isArray()){
						JsonValue subDetail = fSubs[0];
						if (subDetail.isObject()){				
							return HostUrlGetString(subDetail["url"].asString());
						}	
					}
				}
			}
		}
	}
    return "";
}
