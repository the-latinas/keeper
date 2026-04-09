import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Link, useNavigate } from "@tanstack/react-router";
import { LogOut, UserIcon } from "lucide-react";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
	DropdownMenu,
	DropdownMenuContent,
	DropdownMenuGroup,
	DropdownMenuItem,
	DropdownMenuLabel,
	DropdownMenuSeparator,
	DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { logout } from "@/lib/api";

interface DonorUser {
	username?: string;
	email?: string;
	full_name?: string;
}

export default function DonorNav({ user }: { user: DonorUser | null }) {
	const navigate = useNavigate();
	const queryClient = useQueryClient();

	const displayName = user?.full_name || user?.username || "Donor";
	const initials = displayName[0]?.toUpperCase() ?? "D";

	const { mutate: signOut } = useMutation({
		mutationFn: logout,
		onSettled: () => {
			queryClient.setQueryData(["auth", "me"], null);
			queryClient.invalidateQueries({ queryKey: ["auth"] });
			navigate({ to: "/login" });
		},
	});

	return (
		<nav className="sticky top-0 z-50 border-b border-border bg-white/90 backdrop-blur-md">
			<div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
				<Link to="/" className="flex items-center gap-3">
					<span className="font-heading text-xl font-semibold tracking-tight text-foreground">
						Keeper
					</span>
				</Link>

				<DropdownMenu>
					<DropdownMenuTrigger className="flex cursor-pointer items-center gap-3 rounded-lg px-2 py-1 transition-colors hover:bg-muted focus:outline-none">
						<div className="hidden text-right sm:block">
							<div className="font-body text-sm font-medium text-foreground">
								{displayName}
							</div>
							<div className="font-body text-xs text-muted-foreground">
								{user?.email}
							</div>
						</div>
						<Avatar className="h-9 w-9">
							<AvatarFallback className="bg-primary/10 font-body text-sm font-semibold text-primary">
								{initials}
							</AvatarFallback>
						</Avatar>
					</DropdownMenuTrigger>

					<DropdownMenuContent align="end" sideOffset={8}>
						<DropdownMenuGroup className="sm:hidden">
							<DropdownMenuLabel>
								<div className="font-body text-sm font-medium text-foreground">
									{displayName}
								</div>
								<div className="font-body text-xs text-muted-foreground">
									{user?.email}
								</div>
							</DropdownMenuLabel>
						</DropdownMenuGroup>
						<DropdownMenuSeparator className="sm:hidden" />

						<DropdownMenuItem
							className="focus:bg-muted focus:text-foreground"
							onClick={() => navigate({ to: "/account" })}
						>
							<UserIcon className="h-4 w-4" />
							Account
						</DropdownMenuItem>

						<DropdownMenuSeparator />

						<DropdownMenuItem
							variant="destructive"
							className="focus:bg-red-50 focus:text-red-600"
							onClick={() => signOut()}
						>
							<LogOut className="h-4 w-4" />
							Sign Out
						</DropdownMenuItem>
					</DropdownMenuContent>
				</DropdownMenu>
			</div>
		</nav>
	);
}
