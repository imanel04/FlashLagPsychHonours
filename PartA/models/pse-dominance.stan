
data {
  int<lower=0> N;                 // number of data points
  int<lower=0> n_subjects;        // number of subjects
  array[N] int id;                // subject ID  
  vector[N] y;                    // response variable
  
  // Prior hyperparameter
  real mu_theta_mean;            // prior hyperparameter for population-level intercept 1 (a_mu)
  real<lower=0> mu_theta_sd;     // prior hyperparameter for population-level intercept 2 (b_mu)
  real sigma_theta_mean;                 // prior hyperparameter for populativ-level standard deviation 1 (a_sigma)
  real<lower=0> sigma_theta_sd;          // prior hyperparameter for population level standard deviation 2 (b_sigma)
}


parameters {
  vector <lower=0> [n_subjects] theta;                             // subject-specific intercepts, constrained to zero (truncated normal)
  real <offset = mu_theta_mean, multiplier = mu_theta_sd> mu_theta_hat;          // population-level intercept
  real <offset = sigma_theta_mean, multiplier = sigma_theta_sd> sigma_theta_hat; // population level standard deviation
  real<lower=0> sigma_epsilon;                                                  // standard deviation of the response variable
}

transformed parameters {
  real mu_theta = exp(mu_theta_hat);         // prior log normal distributed
  real <lower = 0> sigma_theta = exp(sigma_theta_hat);   // prior log normal distributed
}


model {
  // Priors
  target += normal_lpdf(mu_theta_hat | mu_theta_mean, mu_theta_sd);
  target += normal_lpdf(sigma_theta_hat | sigma_theta_mean, sigma_theta_sd);
  target += normal_lpdf(theta | mu_theta, sigma_theta);
  target += log(1/sigma_epsilon^2); // Jeffreys prior on sigma2
  
  // Likelihood
  target += normal_lpdf(y | theta[id], sigma_epsilon);
}

