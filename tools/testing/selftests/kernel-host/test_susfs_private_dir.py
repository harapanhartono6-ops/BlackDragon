#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Exercise automatic private-directory registration and existing app filtering."""
from test_helpers import ROOT, function_body, run_c

source='fs/susfs.c'
code=r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#define CONFIG_KSU_SUSFS_SUS_PATH 1
#define LINUX_VERSION_CODE 0
#define KERNEL_VERSION(a,b,c) (((a)<<16)|((b)<<8)|(c))
#define AS_FLAGS_SUS_PATH 3
#define FUSE_SUPER_MAGIC 0x65735546
#define likely(x) (x)
#define unlikely(x) (x)
#define SUSFS_LOGI(...) ((void)0)
#define SUSFS_LOGE(...) ((void)0)
struct cred {};
struct uid { unsigned int val; };
#define GLOBAL_ROOT_UID ((struct uid){0})
static bool uid_eq(struct uid a,struct uid b) { return a.val==b.val; }
struct super_block { unsigned long s_magic; };
struct inode { unsigned long i_state; unsigned int i_mode; struct uid i_uid; struct super_block *i_sb; };
struct fuse_inode { struct inode inode; };
struct path { void *dentry; };
struct work_struct {};
static struct super_block sb;
static struct inode node;
static struct cred cred;
static struct cred *ksu_cred=&cred;
static bool missing, no_inode, eligible;
static unsigned int uid=10468;
static int overridden, refs, loops;
static struct uid current_uid(void) { return (struct uid){uid}; }
static const struct cred *override_creds(const struct cred *c) { assert(c==ksu_cred && !overridden); overridden++; return &cred; }
static void revert_creds(const struct cred *c) { assert(overridden==1); overridden--; }
static int kern_path(const char *p,int flags,struct path *path) {
 assert(overridden && !strcmp(p,"/data/adb") && !flags);
 if(missing) return -2;
 path->dentry=&node; refs++; return 0;
}
static struct inode *d_backing_inode(void *p) { return no_inode?NULL:&node; }
static void path_put(struct path *p) { refs--; }
static void set_bit(int bit,unsigned long *value) { *value|=1UL<<bit; }
static bool test_bit(int bit,const unsigned long *value) { return *value&(1UL<<bit); }
static void susfs_run_sus_path_loop(void) { loops++; }
static bool susfs_is_current_proc_umounted_app(void) { return eligible; }
static struct fuse_inode *get_fuse_inode(struct inode *i) { return NULL; }
'''
if 'void susfs_mark_ksu_private_dir(' in (ROOT/source).read_text():
    code+='void susfs_mark_ksu_private_dir(void)'+function_body(source,'susfs_mark_ksu_private_dir')
code+='static void susfs_run_extra_works(struct work_struct *work)'+function_body(source,'susfs_run_extra_works')
code+='static bool is_i_uid_not_allowed(unsigned int i_uid)'+function_body(source,'is_i_uid_not_allowed')
visibility=(ROOT/source).read_text().split('bool susfs_is_inode_sus_path(',1)[1]
visibility=visibility[visibility.index('\n{'):visibility.index('\nint susfs_get_data_path')]
code+='bool susfs_is_inode_sus_path(struct inode *inode)'+visibility
code+=r'''
int main(void) {
 node.i_sb=&sb; node.i_mode=S_IFDIR|0700;
 susfs_run_extra_works(NULL);
 assert(test_bit(AS_FLAGS_SUS_PATH,&node.i_state));
 assert(!overridden && !refs && loops==1);
 eligible=true;
 assert(susfs_is_inode_sus_path(&node));
 uid=0;
 assert(!susfs_is_inode_sus_path(&node));
 uid=10468;
 eligible=false; // Trusted callers do not receive the umounted-app flag.
 assert(!susfs_is_inode_sus_path(&node));
 for(int kind=0;kind<5;kind++) {
  node.i_state=0; node.i_mode=S_IFDIR|0700; node.i_uid.val=0;
  missing=kind==0; no_inode=kind==1;
  if(kind==2) node.i_mode=S_IFREG|0600;
  if(kind==3) node.i_mode=S_IFLNK|0777;
  if(kind==4) node.i_uid.val=10468;
  susfs_run_extra_works(NULL);
  assert(!node.i_state && !overridden && !refs);
 }
 missing=false; no_inode=false; node.i_uid.val=0;
 susfs_run_extra_works(NULL);
 assert(test_bit(AS_FLAGS_SUS_PATH,&node.i_state));
 node.i_state=0; ksu_cred=NULL;
 int previous_loops=loops;
 susfs_run_extra_works(NULL);
 assert(!node.i_state && loops==previous_loops && !overridden && !refs);
 puts("PASS: SUSFS private directory registration, app-only filtering and failure cleanup");
}
'''
run_c(code)

# Execute the production zygote startup branch and its deferred callback.
boot='drivers/kernelsu/runtime/ksud_integration.c'
startup=function_body(boot,'ksu_handle_execveat_ksud')
startup=startup[startup.index('\n\tif (unlikely(first_zygote'):startup.rindex('\n\treturn 0;')]
callback=function_body(boot,'on_post_fs_data_cbfun')
startup_code=r'''
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#define CONFIG_KSU_SUSFS_SUS_PATH 1
#define unlikely(x) (x)
#define pr_info(...) ((void)0)
#define TWA_RESUME 0
#define rcu_read_lock() ((void)0)
#define rcu_read_unlock() ((void)0)
#define rcu_dereference(p) (p)
struct callback_head { void (*func)(struct callback_head *); };
struct task_struct { struct task_struct *real_parent; };
static struct task_struct parent,task={&parent};
#define current (&task)
struct filename { const char *name; };
static struct filename file={"/system/bin/app_process64"};
static struct filename *filename=&file;
static int argv_value;
static int *argv=&argv_value;
static bool first_zygote=true,in_probe;
static const char app_process[]="/system/bin/app_process";
static int marks,events,stops;
static bool check_argv(int value,int index,const char *s,char *buf,int size) { return true; }
static void susfs_mark_ksu_private_dir(void) { assert(!in_probe);marks++; }
static void on_post_fs_data(void) { events++; }
static void stop_execve_hook(void) { stops++; }
static int task_work_add(struct task_struct *t,struct callback_head *cb,int mode) { return 0; }
static void on_post_fs_data_cbfun(struct callback_head *cb)
'''+callback+r'''
static struct callback_head on_post_fs_data_cb={on_post_fs_data_cbfun};
static void startup(void) {
'''+startup+r'''
}
int main(void) {
#ifdef KSU_KPROBES_HOOK
 in_probe=true;
#endif
 startup();
 in_probe=false;
#ifdef KSU_KPROBES_HOOK
 assert(!marks);
#else
 assert(marks==1);
#endif
 on_post_fs_data_cbfun(&on_post_fs_data_cb);
 assert(marks==1 && events==1 && stops==1);
 puts("PASS: SUSFS startup registration uses process context in both hook backends");
}
'''
run_c(startup_code)
run_c('#define KSU_KPROBES_HOOK 1\n'+startup_code)
