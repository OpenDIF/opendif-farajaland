import type {User as SludiUser} from "../types/user.sludi";
import {Button} from "@/components/ui/button";
import {Globe, User, Search} from "lucide-react";
import {Link} from "react-router-dom";
import {useEffect, useState} from "react";
import {useAuthContext} from "@asgardeo/auth-react";

export function Header() {
    const [user, setUser] = useState<SludiUser | null>(null);

    useEffect(() => {
        try {
            setUser(user)
        } catch (error) {
            console.error("Error parsing user data:", error)
        }
    }, [])

    const {state, getBasicUserInfo} = useAuthContext()

    useEffect(() => {
        const fetchUserInfo = async () => {
            if (state.isAuthenticated) {
                const basicUserInfo = await getBasicUserInfo()

                setUser({
                    authenticated: false,
                    loginTime: "",
                    mobileNumber: "9471234567",
                    name: basicUserInfo.displayName!,
                    email: basicUserInfo.email!,
                    nic: "199512345678"
                })

                localStorage.setItem(
                    "sludi_user",
                    JSON.stringify({
                        name: "Nuwan Fernando",
                        nic: "199512345678",
                        sludiNumber: "434343344334",
                        mobileNumber: "94712345678",
                        email: basicUserInfo.email,
                        authenticated: true,
                        loginTime: new Date().toISOString(),
                    }),
                )
            }
        }
        fetchUserInfo()
    }, [state]);

    return (
        <header className="bg-white border-b border-border shadow-sm">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between h-16">
                    {/* Logo and Title */}
                    <Link to="/">
                        <div className="flex items-center space-x-4">
                            <div className="flex-shrink-0">
                                <img src="/sri-lankan-coat-of-arms.png" alt="Sri Lankan Coat of Arms"
                                     className="h-10 w-10"/>
                            </div>
                            <div>
                                <h1 className="text-lg font-semibold text-foreground font-sans">Online Passport
                                    Application System</h1>
                                <p className="text-sm text-muted-foreground">Department of Immigration and
                                    Emigration</p>
                            </div>
                        </div>
                    </Link>

                    {/* Navigation and Language Options */}
                    <div className="flex items-center space-x-4">
                        <Button variant="ghost" size="sm" asChild>
                            <a href="/status" className="flex items-center">
                                <Search className="h-4 w-4 mr-2"/>
                                Track Status
                            </a>
                        </Button>

                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            <Globe className="h-4 w-4 mr-2"/>
                            English
                        </Button>
                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            සිංහල
                        </Button>
                        <Button variant="outline" size="sm" className="text-sm bg-transparent">
                            தமிழ்
                        </Button>
                        {state.isAuthenticated ? (
                            <>
                                <Button variant="ghost" size="sm">
                                    <User className="h-4 w-4 mr-2"/>
                                    {state.displayName}
                                </Button>
                            </>
                        ) : (
                            <Link to="/login" className="flex items-center">
                                <User className="h-4 w-4 mr-2"/>
                                Login
                            </Link>
                        )}
                    </div>
                </div>
            </div>
        </header>
    )
}
