------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2012-2014, AdaCore                     --
--                                                                          --
--  This library is free software;  you can redistribute it and/or modify   --
--  it under terms of the  GNU General Public License  as published by the  --
--  Free Software  Foundation;  either version 3,  or (at your  option) any --
--  later version. This library is distributed in the hope that it will be  --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    --
--                                                                          --
--  As a special exception under Section 7 of GPL version 3, you are        --
--  granted additional permissions described in the GCC Runtime Library     --
--  Exception, version 3.1, as published by the Free Software Foundation.   --
--                                                                          --
--  You should have received a copy of the GNU General Public License and   --
--  a copy of the GCC Runtime Library Exception along with this program;    --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see   --
--  <http://www.gnu.org/licenses/>.                                         --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  This implements the WebSocket protocol as defined in RFC-6455

with Ada.Strings.Unbounded;
with AWS.Status;

private with Interfaces;

package AWS.Net.WebSocket is

   use Ada.Strings.Unbounded;

   type Object is new Net.Socket_Type with private;
   type Object_Class is access Object'Class;

   No_Object : constant Object'Class;

   type Kind_Type
     is (Unknown, Connection_Open, Text, Binary, Ping, Pong, Connection_Close);
   --  Data Frame Kind

   type Error_Type is
     (Normal_Closure,
      Going_Away,
      Protocol_Error,
      Unsupported_Data,
      No_Status_Received,
      Abnormal_Closure,
      Invalid_Frame_Payload_Data,
      Policy_Violation,
      Message_Too_Big,
      Mandatory_Extension,
      Internal_Server_Error,
      TLS_Handshake,
      Cannot_Resolve_Error,
      User_01,              -- User's defined error code
      User_02,
      User_03,
      User_04,
      User_05);

   --
   --  The following three methods are the one to override or redefine. In fact
   --  the default Send implementation should be ok for most usages.
   --

   function Create
     (Socket  : Socket_Access;
      Request : AWS.Status.Data) return Object'Class;
   --  Create a new instance of the WebSocket, this is used by AWS internal
   --  server to create a default WebSocket if no other constructor are
   --  provided. It is also needed when deriving from WebSocket.

   procedure On_Message (Socket : in out Object; Message : String) is null;
   --  Default implementation does nothing, it needs to be overriden by the
   --  end-user. This is the callback that will get activated for every server
   --  incoming data. It is also important to keep in mind that the thread
   --  handling this WebSocket won't be released until the procedure returns.
   --  So the code inside this routine should be small and most importantly not
   --  wait for an event to occur otherwise other requests won't be served.

   procedure On_Message (Socket : in out Object; Message : Unbounded_String);
   --  Same a above but takes an Unbounded_String. This is supposed to be
   --  overriden when handling large messages otherwise a stack-overflow could
   --  be raised. The default implementation of this procedure to to call the
   --  On_Message above with a string.
   --
   --  So either this version is overriden to handle the incoming messages or
   --  the one above if the messages are known to be small.

   procedure On_Open (Socket : in out Object; Message : String) is null;
   --  As above but activated when a WebSocket is opened

   procedure On_Close (Socket : in out Object; Message : String) is null;
   --  As above but activated when a WebSocket is closed

   procedure On_Error (Socket : in out Object; Message : String) is null;
   --  As above but activated when a WebSocket error is detected

   procedure Send
     (Socket    : in out Object;
      Message   : String;
      Is_Binary : Boolean := False);
   --  This default implementation just send a message to the client. The
   --  message is sent in a single chunk (not fragmented).

   procedure Send
     (Socket    : in out Object;
      Message   : Unbounded_String;
      Is_Binary : Boolean := False);
   --  Same as above but can be used for large messages. The message is
   --  possibly sent fragmented.

   procedure Send
     (Socket    : in out Object;
      Message   : Stream_Element_Array;
      Is_Binary : Boolean := True);
   --  As above but default is a binary message

   procedure Close
     (Socket  : in out Object;
      Message : String;
      Error   : Error_Type := Normal_Closure);
   --  Send a close frame to the WebSocket

   --
   --  Simple accessors to WebSocket state
   --

   function Kind (Socket : Object) return Kind_Type;
   --  Returns the message kind of the current read data

   function Protocol_Version (Socket : Object) return Natural;
   --  Returns the version of the protocol for this WebSocket

   function URI (Socket : Object) return String;
   --  Returns the URI for the WebSocket

   function Origin (Socket : Object) return String;
   --  Returns the Origin of the WebSocket. That is the value of the Origin
   --  header of the client which has opened the socket.

   function Request (Socket : Object) return AWS.Status.Data;
   --  Returns Request of the WebSocket. That is the HTTP-request
   --  of the client which has opened the socket.

   function Error (Socket : Object) return Error_Type;
   --  Returns the current error type

   function End_Of_Message (Socket : Object) return Boolean;
   --  Returns True if we have read a whole message

   --
   --  Socket's methods that must be overriden
   --

   overriding procedure Shutdown
     (Socket : Object;
      How    : Shutmode_Type := Shut_Read_Write);
   --  Shutdown the socket

   overriding function Get_FD (Socket : Object) return FD_Type;
   --  Returns the file descriptor associated with the socket

   overriding function Peer_Addr (Socket : Object) return String;
   --  Returns the peer name/address

   overriding function Peer_Port (Socket : Object) return Positive;
   --  Returns the port of the peer socket

   overriding function Get_Addr (Socket : Object) return String;
   --  Returns the name/address of the socket

   overriding function Get_Port (Socket : Object) return Positive;
   --  Returns the port of the socket

   overriding function Errno (Socket : Object) return Integer;
   --  Returns and clears error state in socket

   overriding function Get_Send_Buffer_Size (Socket : Object) return Natural;
   --  Returns the internal socket send buffer size.
   --  Do not confuse with buffers for the AWS.Net.Buffered operations.

   overriding function Get_Receive_Buffer_Size
     (Socket : Object) return Natural;
   --  Returns the internal socket receive buffer size.
   --  Do not confuse with buffers for the AWS.Net.Buffered operations.

   --
   --  Socket reference
   --

   type UID is range 0 .. 2**31;

   function Get_UID (Socket : Object) return UID;
   --  Returns a unique id for the given socket. The uniqueness for this socket
   --  is guaranteed during the lifetime of the application.

private

   type Internal_State is record
      Kind  : Kind_Type := Unknown;
      Errno : Interfaces.Unsigned_16 := Interfaces.Unsigned_16'Last;
   end record;

   type Internal_State_Access is access Internal_State;

   type Protocol_State;
   type Protocol_State_Access is access Protocol_State;

   type Object is new Net.Socket_Type with record
      Socket  : Net.Socket_Access;
      Id      : UID;
      Request : AWS.Status.Data;
      Version : Natural;
      State   : Internal_State_Access;
      P_State : Protocol_State_Access;
   end record;

   --  Routines read/write from a WebSocket, this handles the WebSocket
   --  protocol.

   overriding procedure Send
     (Socket : Object;
      Data   : Stream_Element_Array;
      Last   : out Stream_Element_Offset);

   overriding procedure Receive
     (Socket : Object;
      Data   : out Stream_Element_Array;
      Last   : out Stream_Element_Offset);

   --  Routine without implementation for a WebSocket

   overriding procedure Bind
     (Socket        : in out Object;
      Port          : Natural;
      Host          : String      := "";
      Reuse_Address : Boolean     := False;
      Family        : Family_Type := Family_Unspec) is null;

   overriding procedure Listen
     (Socket : Object; Queue_Size : Positive := 5) is null;

   overriding procedure Accept_Socket
     (Socket : Socket_Type'Class; New_Socket : in out Object) is null;

   overriding procedure Connect
     (Socket : in out Object;
      Host   : String;
      Port   : Positive;
      Wait   : Boolean     := True;
      Family : Family_Type := Family_Unspec) is null;

   overriding procedure Socket_Pair (S1, S2 : out Object) is null;

   overriding function Pending
     (Socket : Object) return Stream_Element_Count;

   overriding function Is_Listening (Socket : Object) return Boolean;

   overriding procedure Set_Send_Buffer_Size
     (Socket : Object; Size : Natural) is null;

   overriding procedure Set_Receive_Buffer_Size
     (Socket : Object; Size : Natural) is null;

   overriding procedure Free (Socket : in out Object);

   No_Object : constant Object'Class :=
                 Object'
                   (Net.Socket_Type with
                    Socket  => null,
                    Id      => 0,
                    Request => <>,
                    Version => 0,
                    State   => null,
                    P_State => null);

   --  Error codes corresponding to all errors

   Error_Code : constant array (Error_Type) of Interfaces.Unsigned_16 :=
                  (Normal_Closure             => 1000,
                   Going_Away                 => 1001,
                   Protocol_Error             => 1002,
                   Unsupported_Data           => 1003,
                   No_Status_Received         => 1005,
                   Abnormal_Closure           => 1006,
                   Invalid_Frame_Payload_Data => 1007,
                   Policy_Violation           => 1008,
                   Message_Too_Big            => 1009,
                   Mandatory_Extension        => 1010,
                   Internal_Server_Error      => 1011,
                   TLS_Handshake              => 1015,
                   Cannot_Resolve_Error       => 0000,
                   User_01                    => 3000,
                   User_02                    => 3001,
                   User_03                    => 3002,
                   User_04                    => 3003,
                   User_05                    => 3004);

end AWS.Net.WebSocket;
