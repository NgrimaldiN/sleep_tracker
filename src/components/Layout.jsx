import React from 'react';
import { Moon, BarChart3, ListTodo, PlusCircle } from 'lucide-react';
import { cn } from '../lib/utils';

export function Layout({ children, activeTab, setActiveTab }) {
    return (
        <div className="min-h-screen bg-zinc-950 text-zinc-100 font-sans selection:bg-indigo-500/30">
            <div className="max-w-3xl mx-auto min-h-screen flex flex-col border-x border-zinc-900/50 shadow-2xl shadow-black">

                {/* Header */}
                <header className="p-6 border-b border-zinc-900 bg-zinc-950/80 backdrop-blur-xl sticky top-0 z-10">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-indigo-500/10 rounded-xl ring-1 ring-indigo-500/20">
                                <Moon className="w-6 h-6 text-indigo-400" />
                            </div>
                            <div>
                                <h1 className="text-xl font-bold bg-gradient-to-br from-white to-zinc-400 bg-clip-text text-transparent">
                                    Sleep Optimizer
                                </h1>
                                <p className="text-xs text-zinc-500 font-medium tracking-wide uppercase">Personal Tracker</p>
                            </div>
                        </div>
                    </div>
                </header>

                {/* Main Content */}
                <main className="flex-1 p-6 relative">
                    <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
                        {children}
                    </div>
                </main>

                {/* Navigation */}
                <nav className="sticky bottom-6 mx-6 mb-6 rounded-2xl bg-zinc-900/90 backdrop-blur-md border border-zinc-800/50 p-2 shadow-xl ring-1 ring-black/20">
                    <ul className="flex items-center justify-around relative">
                        <NavItem
                            icon={<ListTodo className="w-5 h-5" />}
                            label="Habits"
                            isActive={activeTab === 'habits'}
                            onClick={() => setActiveTab('habits')}
                        />
                        <NavItem
                            icon={<PlusCircle className="w-5 h-5" />}
                            label="Log Sleep"
                            isActive={activeTab === 'log'}
                            onClick={() => setActiveTab('log')}
                        />
                        <NavItem
                            icon={<BarChart3 className="w-5 h-5" />}
                            label="Insights"
                            isActive={activeTab === 'dashboard'}
                            onClick={() => setActiveTab('dashboard')}
                        />
                    </ul>
                </nav>
            </div>
        </div>
    );
}

function NavItem({ icon, label, isActive, onClick }) {
    return (
        <li className="flex-1">
            <button
                onClick={onClick}
                className={cn(
                    "w-full flex flex-col items-center gap-1 py-3 px-4 rounded-xl transition-all duration-300 ease-out group relative overflow-hidden",
                    isActive
                        ? "text-indigo-400 bg-indigo-500/10"
                        : "text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800/50"
                )}
            >
                <div className={cn("relative z-10 transition-transform duration-300", isActive && "scale-110")}>
                    {icon}
                </div>
                <span className="text-[10px] font-medium tracking-wide relative z-10">{label}</span>

                {isActive && (
                    <div className="absolute inset-0 bg-gradient-to-tr from-indigo-500/10 to-purple-500/10 opacity-100 transition-opacity" />
                )}
            </button>
        </li>
    );
}
