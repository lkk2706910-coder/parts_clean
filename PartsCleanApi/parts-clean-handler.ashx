<%@ WebHandler Language="C#" Class="PartsCleanHandler" %>

using System;
using System.IO;
using System.Text;
using System.Web;

public class PartsCleanHandler : IHttpHandler
{
    private static readonly object _lock = new object();

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.ContentEncoding = Encoding.UTF8;

        var action = (context.Request["mode"] ?? "").ToLowerInvariant();

        try
        {
            switch (action)
            {
                case "load":
                    HandleLoad(context);
                    break;
                case "save":
                    HandleSave(context);
                    break;
                default:
                    WriteError(context, "Unknown mode");
                    break;
            }
        }
        catch (Exception ex)
        {
            WriteError(context, ex.Message);
        }
    }

    private void HandleLoad(HttpContext context)
    {
        var partsId = (context.Request["partsId"] ?? "").Trim();
        if (string.IsNullOrEmpty(partsId))
        {
            WriteError(context, "Missing partsId");
            return;
        }

        string path = GetCsvPath(partsId);
        if (!File.Exists(path))
        {
            context.Response.Write("{\"success\":true,\"rows\":[]}");
            return;
        }

        var rowsJson = CsvToJson(path);
        context.Response.Write("{\"success\":true,\"rows\":" + rowsJson + "}");
    }

    private void HandleSave(HttpContext context)
    {
        var partsId = (context.Request["partsId"] ?? "").Trim();
        if (string.IsNullOrEmpty(partsId))
        {
            WriteError(context, "Missing partsId");
            return;
        }

        var json = context.Request["rows"] ?? "";
        if (string.IsNullOrEmpty(json))
        {
            WriteError(context, "Missing rows json");
            return;
        }

        string path = GetCsvPath(partsId);
        Directory.CreateDirectory(Path.GetDirectoryName(path));

        lock (_lock)
        {
            JsonToCsv(json, path);
        }

        context.Response.Write("{\"success\":true}");
    }

    private string GetCsvPath(string partsId)
    {
        string baseDir = HttpContext.Current.Server.MapPath("~/PartsCleanAppData");
        return Path.Combine(baseDir, partsId + ".csv");
    }

    private void WriteError(HttpContext context, string message)
    {
        context.Response.Write("{\"success\":false,\"error\":\"" + EscapeJson(message) + "\"}");
    }

    private string EscapeJson(string s)
    {
        if (string.IsNullOrEmpty(s)) return string.Empty;
        return s.Replace("\\", "\\\\").Replace("\"", "\\\"");
    }

    // 期望 rows 為 JSON array，每個元素是一個 object，欄位名稱固定。
    private void JsonToCsv(string json, string path)
    {
        // 簡易處理：目前直接把 JSON 陣列寫進檔案，
        // 副檔名雖然是 .csv，但內容是 JSON，方便前後端處理。
        File.WriteAllText(path, json, Encoding.UTF8);
    }

    private string CsvToJson(string path)
    {
        // 對應上面的 JsonToCsv：直接把檔案內容（JSON 字串）回傳
        return File.ReadAllText(path, Encoding.UTF8);
    }

    public bool IsReusable { get { return true; } }
}
