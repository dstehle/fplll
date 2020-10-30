#include "enum.cu"
#include "testdata.h"
#include "util.h"

#include <array>
#include <functional>

inline void gpu_test()
{
  constexpr unsigned int levels               = 14;
  constexpr unsigned int dimensions_per_level = 3;
  constexpr unsigned int dimensions           = levels * dimensions_per_level;
  constexpr unsigned int max_nodes_per_level  = 3000;
  constexpr unsigned int start_point_dim      = 8;
  constexpr unsigned int mu_n                 = dimensions + start_point_dim;

  const Opts<levels, dimensions_per_level, max_nodes_per_level> opts = {
      50, .5, 1500, 8, start_point_dim, 32 * 256};

  const std::array<std::array<float, mu_n>, mu_n> &mu = test_mu_knapsack_big;

  std::vector<std::array<enumi, start_point_dim>> start_points;
  std::array<enumi, start_point_dim> x;
  x[start_point_dim - 1] = -1;
  enumf radius           = find_initial_radius(mu) * 1.5;
  std::function<void(const std::array<float, start_point_dim> &)> callback =
      [&start_points](const auto &a) { start_points.push_back(a); };
  do
  {
    ++x[start_point_dim - 1];
  } while (!naive_enum_recursive<start_point_dim, mu_n>(x, 0, 0, mu, mu_n - 1, radius * radius,
                                                        callback));

  //for (auto x : start_points[2275286])
  //{
  //  std::cout << x << ", ";
  //}
  //std::cout << std::endl;

  search<levels, dimensions_per_level, max_nodes_per_level, start_point_dim>(mu, start_points,
                                                                             opts);
}

template <typename Dummy> inline void gpu_test4d()
{
  constexpr unsigned int levels               = 3;
  constexpr unsigned int dimensions_per_level = 1;
  constexpr unsigned int dimensions           = levels * dimensions_per_level;
  constexpr unsigned int max_nodes_per_level  = 2000;
  constexpr unsigned int start_point_dim      = 1;
  constexpr unsigned int mu_n                 = dimensions + start_point_dim;

  const Opts<levels, dimensions_per_level, max_nodes_per_level> opts = {
      50, .5, 1500, 8, start_point_dim, 32 * 256};

  std::array<std::array<float, mu_n>, mu_n> test_mu_tiny = {
      {{3, 2, 4, 3}, {0, 3, 4, 2}, {0, 0, 3, 3}, {0, 0, 0, 2}}};
  const std::array<std::array<float, mu_n>, mu_n> &mu = test_mu_tiny;

  std::vector<std::array<enumi, start_point_dim>> start_points;
  start_points.push_back({0});
  start_points.push_back({1});

  search<levels, dimensions_per_level, max_nodes_per_level, start_point_dim>(mu, start_points, ops);
}

inline void cpu_test()
{
  constexpr unsigned int levels               = 5;
  constexpr unsigned int dimensions_per_level = 4;
  constexpr unsigned int dimensions           = levels * dimensions_per_level;
  constexpr unsigned int max_nodes_per_level  = 200000;

  const std::array<std::array<float, dimensions>, dimensions> &host_mu = test_mu_small;

  single_thread group;
  PrefixCounter<single_thread, 1> prefix_counter;

  SubtreeEnumerationBuffer<levels, dimensions_per_level, max_nodes_per_level> buffer(
      new unsigned char[SubtreeEnumerationBuffer<levels, dimensions_per_level,
                                                 max_nodes_per_level>::memory_size_in_bytes]);
  buffer.init(group);

  std::unique_ptr<enumf[]> mu(new enumf[dimensions * dimensions]);
  std::unique_ptr<enumf[]> local_mu(new enumf[dimensions_per_level * dimensions_per_level]);
  std::unique_ptr<enumf[]> rdiag(new enumf[dimensions]);
  for (unsigned int i = 0; i < dimensions; ++i)
  {
    rdiag[i] = host_mu[i][i];
    for (unsigned int j = 0; j < dimensions; ++j)
    {
      mu[i * dimensions + j] = host_mu[i][j] / rdiag[i];
    }
    rdiag[i] = rdiag[i] * rdiag[i];
  }
  enumf radius             = find_initial_radius(host_mu) * 1.1;
  uint32_t radius_location = float_to_int_order_preserving_bijection(radius * radius);

  const unsigned int index = buffer.add_node(0, 0);
  for (unsigned int i = 0; i < dimensions; ++i)
  {
    buffer.set_center_partsum(0, index, i, 0);
  }
  buffer.init_subtree(0, index, 0, 0);

  unsigned int counter            = 0;
  unsigned long long node_counter = 0;
  StrategyOpts opts               = {5, .5, max_nodes_per_level / 2};
  clear_level<single_thread, 1, levels, dimensions_per_level, max_nodes_per_level>(
      group, prefix_counter, &counter, buffer, 0, Matrix(mu.get(), dimensions), rdiag.get(),
      &radius_location, opts, PerfCounter(&node_counter));
}

inline void cpu_test4d()
{
  constexpr unsigned int levels               = 1;
  constexpr unsigned int dimensions_per_level = 4;
  constexpr unsigned int dimensions           = levels * dimensions_per_level;
  constexpr unsigned int max_nodes_per_level  = 100;

  std::array<std::array<float, dimensions>, dimensions> host_mu = {
      {{3, 2, 4, 3}, {0, 3, 4, 2}, {0, 0, 3, 3}, {0, 0, 0, 2}}};

  single_thread group;
  PrefixCounter<single_thread, 1> prefix_counter;

  SubtreeEnumerationBuffer<levels, dimensions_per_level, max_nodes_per_level> buffer(
      new unsigned char[SubtreeEnumerationBuffer<levels, dimensions_per_level,
                                                 max_nodes_per_level>::memory_size_in_bytes]);
  buffer.init(group);

  std::unique_ptr<enumf[]> mu(new enumf[dimensions * dimensions]);
  std::unique_ptr<enumf[]> local_mu(new enumf[dimensions_per_level * dimensions_per_level]);
  std::unique_ptr<enumf[]> rdiag(new enumf[dimensions]);
  for (unsigned int i = 0; i < dimensions; ++i)
  {
    rdiag[i] = host_mu[i][i];
    for (unsigned int j = 0; j < dimensions; ++j)
    {
      mu[i * dimensions + j] = host_mu[i][j] / rdiag[i];
    }
    rdiag[i] = rdiag[i] * rdiag[i];
  }
  enumf radius             = 3.01;
  uint32_t radius_location = float_to_int_order_preserving_bijection(radius * radius);

  const unsigned int index = buffer.add_node(0, 0);
  for (unsigned int i = 0; i < dimensions; ++i)
  {
    buffer.set_center_partsum(0, index, i, 0);
  }
  buffer.init_subtree(0, index, 0, 0);

  unsigned int counter            = 0;
  unsigned long long node_counter = 0;
  StrategyOpts opts               = {5, .5, max_nodes_per_level / 2};
  clear_level<single_thread, 1, levels, dimensions_per_level, max_nodes_per_level>(
      group, prefix_counter, &counter, buffer, 0, Matrix(mu.get(), dimensions), rdiag.get(),
      &radius_location, opts, PerfCounter(&node_counter));
}

int main()
{
  gpu_test();

  return 0;
}
