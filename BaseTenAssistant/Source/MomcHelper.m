//
// MomcHelper.m
// BaseTen Setup
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//
 
#import <alloca.h>
#import <errno.h>
#import <signal.h>
#import <stdio.h>
#import <string.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <unistd.h>
#import <Foundation/Foundation.h>
#import "Constants.h"


#if 0
#define debug(...) debug1( __LINE__, __VA_ARGS__ )
#else
#define debug(...)
#endif


int usr1Received = 0;


void debug1 (int line, char* format, ...)
{
    va_list ap;
    va_start (ap, format);

    fprintf (stderr, "%d: ", line);
    vfprintf (stderr, format, ap);
    fprintf (stderr, "\n");
        
    va_end (ap);
}


void handler (int signal)
{
    usr1Received = 1;
}


int main (int argc, char** argv)
{
    /*
     * I'm not quite sure, whether mkstemps locks the descriptor or not; the manual page doesn't
     * indicate this. To be on the safe side, we make sure that the lock is acquired by the
     * same process.
     */
    
    struct stat sb;
    char* modelName = argv [1];
    if (0 != argv && 0 == stat (modelName, &sb) && S_ISDIR (sb.st_mode))
    {
        char* suffix = ".xcdatamodel";
        char* ptr = strstr (modelName, suffix);
        //Check the suffix
        if (NULL != ptr && strlen (suffix) == strlen(ptr))
        {
            char* format = "/tmp/momcHelper.XXXXXX.mom";
            size_t size = strlen (format) + 1;
            char* targetName = alloca (size);
            
            strlcpy (targetName, format, size);
            char* ptr = strrchr (format, 'X');
            //Get the suffix length before the first X
            if (-1 != mkstemps (targetName, strlen (format) - (ptr - format) - 1))
            {
                debug ("Trying to find momc");
                char* momcPath = NULL;
                
                {
                    char* paths [] = {
                        (getenv ("MOMC") ?: ""),
						"/Developer/usr/bin/momc", // Patch from Gustavo Moya Ortiz on 20080311, case #127.
                        "/Developer/Library/Xcode/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc",
                        "/Library/Application Support/Apple/Developer Tools/Plug-ins/XDCoreDataModel.xdplugin/Contents/Resources/momc",
                        NULL
                    };
                    
                    int i = 0;
                    struct stat sb;
                    while (NULL != paths [i])
                    {
                        if (0 < strlen (paths [i]))
                        {
                            int status = stat (paths [i], &sb);
                            //FIXME: additional checks?
                            if (0 == status)
                                momcPath = paths [i];
                            else
                            {
                                char* reason = strerror (errno);
                                fprintf (stderr, 
                                         "Couldn't run momc at <%s>. stat(2) failed for the following reason: %s\n",
                                         paths [i], reason);
                            }
                        }
                        i++;
                    }
                }
                
                if (NULL != momcPath)
                {
                    sigset_t mask, oldmask;
                    char* options [] = {momcPath, modelName, targetName, NULL};
                    
                    debug ("Target name: %s", targetName);
                    
                    sigemptyset (&mask);
                    sigaddset (&mask, SIGUSR1);
                    
                    //Post the notification
                    sigprocmask (SIG_BLOCK, &mask, &oldmask);
                    signal (SIGUSR1, &handler);
                    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
                    debug ("Posting the notification");
                    NSDistributedNotificationCenter* nc = [NSDistributedNotificationCenter defaultCenter];
                    debug ("Nc: %p", nc);
                    [nc postNotificationName: kBXMomcHelperTargetFile
                                      object: [NSString stringWithUTF8String: targetName]
                                    userInfo: nil
                          deliverImmediately: YES];
                    [pool release];
                    
                    //Wait for the signal
                    debug ("Beginning to wait");
                    while (!usr1Received)
                        sigsuspend (&oldmask);
                    sigprocmask (SIG_UNBLOCK, &mask, NULL);
                    
                    //Run momc
                    debug ("Running momc");
                    execv (momcPath, options);
                }                
            }
        }
    }
    
    return 1;
}
