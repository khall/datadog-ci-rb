#include <ruby.h>
#include <ruby/debug.h>

// Utils
static int prefix(const char *pre, const char *str)
{
  return strncmp(pre, str, strlen(pre));
}

// const
#define DD_COV_TARGET_FILES 1
#define DD_COV_TARGET_LINES 2

// Data structure
struct dd_cov_data
{
  char *root;
  int mode;
  VALUE coverage;
};

static void dd_cov_mark(void *ptr)
{
  struct dd_cov_data *dd_cov_data = ptr;
  rb_gc_mark_movable(dd_cov_data->coverage);
}

static void dd_cov_free(void *ptr)
{
  struct dd_cov_data *dd_cov_data = ptr;

  xfree(dd_cov_data);
}

static void dd_cov_compact(void *ptr)
{
  struct dd_cov_data *dd_cov_data = ptr;
  dd_cov_data->coverage = rb_gc_location(dd_cov_data->coverage);
}

const rb_data_type_t dd_cov_data_type = {
    .wrap_struct_name = "dd_cov",
    .function = {
        .dmark = dd_cov_mark,
        .dfree = dd_cov_free,
        .dsize = NULL,
        .dcompact = dd_cov_compact},
    .flags = RUBY_TYPED_FREE_IMMEDIATELY};

static VALUE dd_cov_allocate(VALUE klass)
{
  struct dd_cov_data *dd_cov_data;
  VALUE obj = TypedData_Make_Struct(klass, struct dd_cov_data, &dd_cov_data_type, dd_cov_data);
  dd_cov_data->coverage = rb_hash_new();
  return obj;
}

// DDCov methods
static VALUE dd_cov_initialize(int argc, VALUE *argv, VALUE self)
{
  VALUE opt;
  int mode;

  rb_scan_args(argc, argv, "10", &opt);
  VALUE rb_root = rb_hash_lookup(opt, ID2SYM(rb_intern("root")));
  if (!RTEST(rb_root))
  {
    rb_raise(rb_eArgError, "root is required");
  }

  VALUE rb_mode = rb_hash_lookup(opt, ID2SYM(rb_intern("mode")));
  if (!RTEST(rb_mode) || rb_mode == ID2SYM(rb_intern("files")))
  {
    mode = DD_COV_TARGET_FILES;
  }
  else if (rb_mode == ID2SYM(rb_intern("lines")))
  {
    mode = DD_COV_TARGET_LINES;
  }
  else
  {
    rb_raise(rb_eArgError, "mode is invalid");
  }

  struct dd_cov_data *dd_cov_data;
  TypedData_Get_Struct(self, struct dd_cov_data, &dd_cov_data_type, dd_cov_data);

  dd_cov_data->root = StringValueCStr(rb_root);
  dd_cov_data->mode = mode;

  return Qnil;
}

static void dd_cov_update_line_coverage(rb_event_flag_t event, VALUE data, VALUE self, ID id, VALUE klass)
{
  struct dd_cov_data *dd_cov_data;
  TypedData_Get_Struct(data, struct dd_cov_data, &dd_cov_data_type, dd_cov_data);

  const char *filename = rb_sourcefile();
  if (filename == 0)
  {
    return;
  }

  if (prefix(dd_cov_data->root, filename) != 0)
  {
    return;
  }

  VALUE rb_str_source_file = rb_str_freeze(rb_str_new2(filename));

  if (dd_cov_data->mode == DD_COV_TARGET_FILES)
  {
    rb_hash_aset(dd_cov_data->coverage, rb_str_source_file, Qtrue);
    return;
  }

  if (dd_cov_data->mode == DD_COV_TARGET_LINES)
  {
    VALUE rb_lines = rb_hash_aref(dd_cov_data->coverage, rb_str_source_file);
    if (rb_lines == Qnil)
    {
      rb_lines = rb_ary_new();
      rb_hash_aset(dd_cov_data->coverage, rb_str_source_file, rb_lines);
    }

    VALUE line_number = INT2FIX(rb_sourceline());
    if (rb_ary_includes(rb_lines, line_number) == Qfalse)
    {
      rb_ary_push(rb_lines, line_number);
    }
  }
}

static VALUE dd_cov_start(VALUE self)
{
  // get current thread
  VALUE thval = rb_thread_current();

  // add event hook
  rb_thread_add_event_hook(thval, dd_cov_update_line_coverage, RUBY_EVENT_LINE, self);

  return self;
}

static VALUE dd_cov_stop(VALUE self)
{
  // get current thread
  VALUE thval = rb_thread_current();
  // remove event hook for the current thread
  rb_thread_remove_event_hook(thval, dd_cov_update_line_coverage);

  struct dd_cov_data *dd_cov_data;
  TypedData_Get_Struct(self, struct dd_cov_data, &dd_cov_data_type, dd_cov_data);

  VALUE cov = dd_cov_data->coverage;

  dd_cov_data->coverage = rb_hash_new();

  return cov;
}

void Init_datadog_cov(void)
{
  VALUE mDatadog = rb_define_module("Datadog");
  VALUE mCI = rb_define_module_under(mDatadog, "CI");
  VALUE cDatadogCov = rb_define_class_under(mCI, "Cov", rb_cObject);

  rb_define_alloc_func(cDatadogCov, dd_cov_allocate);

  rb_define_method(cDatadogCov, "initialize", dd_cov_initialize, -1);
  rb_define_method(cDatadogCov, "start", dd_cov_start, 0);
  rb_define_method(cDatadogCov, "stop", dd_cov_stop, 0);
}
