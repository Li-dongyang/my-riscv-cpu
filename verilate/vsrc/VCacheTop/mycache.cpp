#include "testbench.h"

#include "defs.h"
#include "mycache.h"

MyCache::MyCache()
	: ref(this, MEMORY_SIZE)
{
}

void MyCache::reset()
{
	clk = 0;
	reset_ = 1;
	memset(cresp, 0, sizeof(cresp));
	// cresp = 0;
	memset(dreq, 0, sizeof(dreq));

	for (int i = 0; i < 100000; i++) {
		_tick<false, false, false>();
	}

	dev->reset();
	clk = 0;
	reset_ = 0;
	eval();
}

void MyCache::tick()
{
	_tick();
}

void MyCache::enable_statistics(bool enable)
{
	stat.enabled = enable;
}

void MyCache::reset_statistics()
{
	/**
	 * TODO (Lab3, optional) reset statistics information :)
	 */

	 // memset(stat.count, 0, sizeof(stat.count));
	stat.miss_cnt = 0;
	stat.request_cnt = 0;
}

void MyCache::update_statistics()
{
	/**
	 * TODO (Lab3, optional) track statistics information here :)
	 */

	if(VCacheTop->data_ok_for_refcache) {
		stat.request_cnt++;
	}
	if(VCacheTop->fsm_to_miss_for_refcache) {
		stat.miss_cnt++;
	}
}

void MyCache::print_statistics(const std::string &title)
{
	/**
	 * TODO (Lab3, optional) print statistics with title :)
	 *
	 * NOTE: you should use info() to print text.
	 */
	if(!stat.request_cnt) { // in case that we stop test with ctrl^C,and no req was made.
		info("\"%s\": bingo!\n", title.data());
		return;
	}
	float_t hit_rate = 100 - ((float)stat.miss_cnt / stat.request_cnt) * 100;

	info("\"%s\": bingo! hit rate: %f\n", title.data(), hit_rate);
}

auto MyCache::dump() -> MemoryDump
{
	return dev->dump(0, MEMORY_SIZE);
}

void MyCache::run()
{
	DBus dbus(this, VCacheTop, DBusPorts{ dreq, dresp });

	// bind variables to ease testing
	_testbench::top = this;
	_testbench::scope = VCacheTop;
	_testbench::dbus = &dbus;
	_testbench::ref = &ref;

	// default to disable FST tracing
	enable_fst_trace(false);

	run_testbench(_num_workers);
}
