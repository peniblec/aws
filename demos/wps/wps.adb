------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2000-2007                          --
--                                AdaCore                                   --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  This is a very simple Web Page Server using the AWS.Services.Page_Server.

with Ada.Text_IO;

with AWS.Config;
with AWS.Server.Log;
with AWS.Services.Page_Server;

procedure WPS is

   use Ada;

   WS : AWS.Server.HTTP;

   Config : constant AWS.Config.Object := AWS.Config.Get_Current;

begin
   Text_IO.Put_Line ("AWS " & AWS.Version);
   Text_IO.Put_Line
     ("Server port:" & Integer'Image (AWS.Config.Server_Port (Config)));
   Text_IO.Put_Line ("Kill me when you want me to stop or press Q...");

   if AWS.Config.Directory_Browser_Page (Config) /= "" then
      AWS.Services.Page_Server.Directory_Browsing (True);
   end if;

   if AWS.Config.Log_Filename_Prefix (Config) /= "" then
      AWS.Server.Log.Start (WS);
   end if;

   if AWS.Config.Error_Log_Filename_Prefix (Config) /= "" then
      AWS.Server.Log.Start_Error (WS);
   end if;

   AWS.Server.Start (WS, AWS.Services.Page_Server.Callback'Access, Config);

   AWS.Server.Wait (AWS.Server.Q_Key_Pressed);

   Text_IO.Put_Line ("AWS server shutdown in progress...");

   AWS.Server.Shutdown (WS);
end WPS;